namespace PondyConnect.Api.Controllers;

using System.Globalization;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.FoodDelivery;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Services;
using PondyConnect.Api.Hubs;
using PondyConnect.Api.Services;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api")]
public sealed class FoodDeliveryController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly FoodDeliveryDispatchService _foodDispatch;
    private readonly INotificationService _notifications;
    private readonly IIdempotencyService _idempotency;
    private readonly IHubContext<VendorHub> _hubContext;
    private readonly IApplicationDbContext _context;

    public FoodDeliveryController(
        IMediator mediator,
        FoodDeliveryDispatchService foodDispatch,
        INotificationService notifications,
        IIdempotencyService idempotency,
        IHubContext<VendorHub> hubContext,
        IApplicationDbContext context)
    {
        _mediator = mediator;
        _foodDispatch = foodDispatch;
        _notifications = notifications;
        _idempotency = idempotency;
        _hubContext = hubContext;
        _context = context;
    }

    [HttpPost("orders/checkout")]
    [HttpPost("orders")]
    [Authorize]
    [EnableRateLimiting("OrderPolicy")]
    [ProducesResponseType(typeof(CheckoutResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(CartPriceConflictResponse), StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<ActionResult<CheckoutResponse>> Checkout([FromBody] CreateFoodOrderRequest request, CancellationToken ct)
    {
        var idempotencyKey = Request.Headers["Idempotency-Key"].FirstOrDefault();
        var cacheKey = $"food:{Request.Path}:{idempotencyKey}";

        if (!string.IsNullOrWhiteSpace(idempotencyKey))
        {
            var cached = await _idempotency.GetAsync<CheckoutResponse>(cacheKey, ct);
            if (cached is not null)
                return Ok(cached);
        }

        var items = request.Items?.Select(i => new CreateFoodOrderItemRequest(
            i.Name,
            i.Quantity,
            i.UnitPrice,
            i.SpecialInstructions,
            i.SelectedModifierIds)).ToList()
            ?? new List<CreateFoodOrderItemRequest>();
        var cmd = new CreateFoodOrderCommand(
            request.VendorId,
            request.DeliveryAddress,
            request.DeliveryLatitude,
            request.DeliveryLongitude,
            request.PaymentMethod,
            request.VenueId,
            request.Notes,
            items,
            request.RazorpayOrderId,
            request.RazorpayPaymentId,
            request.RazorpaySignature);

        CheckoutResponse result;
        try
        {
            result = await _mediator.Send(cmd, ct);
        }
        catch (CartPriceConflictException ex)
        {
            // Menu prices changed between cart creation and checkout.
            // Return 409 with the live prices so the client can update the
            // cart and prompt the user to review the new total.
            return Conflict(new CartPriceConflictResponse(
                ex.Message,
                ex.LiveItemPrices.ToDictionary(kvp => kvp.Key, kvp => kvp.Value),
                ex.LiveSubTotal,
                ex.LiveTotalAmount));
        }

        if (!string.IsNullOrWhiteSpace(idempotencyKey))
        {
            await _idempotency.SetAsync(cacheKey, result, TimeSpan.FromHours(24), ct);
        }

        // Send FCM push to the vendor so they get alerted even if the app is backgrounded
        _ = _notifications.SendPushToVendorAsync(
            request.VendorId,
            "New Order Received",
            $"Order {result.OrderId} · \u20B9{result.TotalAmount.ToString("0", CultureInfo.InvariantCulture)}",
            new Dictionary<string, string>
            {
                { "type", "new_order" },
                { "order_id", result.OrderId.ToString() },
                { "amount", result.TotalAmount.ToString("0", CultureInfo.InvariantCulture) },
                { "status", result.Status },
            },
            ct);

        // SignalR broadcast so an open KDS screen immediately chimes and reloads.
        _ = _hubContext.Clients.Group($"vendor:{request.VendorId}")
            .SendAsync("NewOrder", new
            {
                orderId = result.OrderId,
                orderNumber = $"ORD-{result.OrderId.ToString().Substring(0, 8).ToUpperInvariant()}",
                vendorId = request.VendorId,
                totalAmount = result.TotalAmount,
                status = result.Status,
            }, ct);

        return Ok(result);
    }

    [HttpGet("orders/{id:guid}")]
    [Authorize]
    [ProducesResponseType(typeof(FoodOrderDetailResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<FoodOrderDetailResponse>> GetOrder(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetFoodOrderQuery(id), ct);
        if (result is null) return NotFound(new { Message = "Order not found." });
        return Ok(result);
    }

    [HttpGet("orders")]
    [HttpGet("orders/my-orders")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<FoodOrderSummaryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FoodOrderSummaryResponse>>> ListOrders([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListUserFoodOrdersQuery(page, pageSize), ct);
        if (result is null) return Ok(Array.Empty<FoodOrderSummaryResponse>());
        return Ok(result);
    }

    [HttpGet("vendors/{vendorId:guid}/menu")]
    [ProducesResponseType(typeof(IReadOnlyList<MenuItemResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MenuItemResponse>>> GetMenu(Guid vendorId, CancellationToken ct)
    {
        var result = await _mediator.Send(new ListMenuItemsQuery(vendorId, true), ct);
        if (result is null) return Ok(Array.Empty<MenuItemResponse>());
        return Ok(result);
    }

    [HttpPost("vendor/menu")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(MenuItemResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<MenuItemResponse>> CreateMenuItem([FromBody] CreateMenuItemRequest request, CancellationToken ct)
    {
        var cmd = new CreateMenuItemCommand(
            null,
            request.Name,
            request.Price,
            request.Category,
            request.VenueId,
            request.Description,
            request.ImageUrl,
            request.IsLateNight);
        var result = await _mediator.Send(cmd, ct);
        return Ok(result);
    }

    [HttpPut("vendor/menu/{id:guid}")]
    [Authorize(Roles = "Vendor")]
    public async Task<IActionResult> UpdateMenuItem(Guid id, [FromBody] UpdateMenuItemRequest request, CancellationToken ct)
    {
        await _mediator.Send(new UpdateMenuItemCommand(id, request.Name, request.Description, request.Category, request.NewPrice), ct);
        return NoContent();
    }

    [HttpPost("vendor/menu/{id:guid}/toggle")]
    [Authorize(Roles = "Vendor")]
    public async Task<IActionResult> ToggleMenuItem(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new ToggleMenuItemCommand(id), ct);
        return NoContent();
    }

    [HttpDelete("vendor/menu/{id:guid}")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteMenuItem(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new DeleteMenuItemCommand(id), ct);
        return NoContent();
    }

    // ── Modifier Groups ──────────────────────────────────────────────────

    [HttpPost("vendor/menu/{itemId:guid}/modifier-groups")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(ModifierGroupResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ModifierGroupResponse>> CreateModifierGroup(
        Guid itemId, [FromBody] CreateModifierGroupRequest request, CancellationToken ct)
    {
        var cmd = new CreateModifierGroupCommand(itemId, request.Name, request.MinSelections, request.MaxSelections, request.SortOrder);
        var result = await _mediator.Send(cmd, ct);
        return Ok(result);
    }

    // ── Modifiers ────────────────────────────────────────────────────────

    [HttpPost("vendor/menu/{itemId:guid}/modifier-groups/{groupId:guid}/modifiers")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(ModifierResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ModifierResponse>> CreateModifier(
        Guid itemId, Guid groupId, [FromBody] CreateModifierRequest request, CancellationToken ct)
    {
        var cmd = new CreateModifierCommand(groupId, request.Name, request.Price, request.IsAvailable, request.SortOrder);
        var result = await _mediator.Send(cmd, ct);
        return Ok(result);
    }

    [HttpPut("vendor/menu/modifiers/{id:guid}")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateModifier(Guid id, [FromBody] UpdateModifierRequest request, CancellationToken ct)
    {
        await _mediator.Send(new UpdateModifierCommand(id, request.Name, request.Price, request.IsAvailable), ct);
        return NoContent();
    }

    [HttpDelete("vendor/menu/modifiers/{id:guid}")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteModifier(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new DeleteModifierCommand(id), ct);
        return NoContent();
    }

    [HttpPost("orders/{id:guid}/cancel")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CancelOrder(Guid id, [FromBody] CancelOrderRequest? request, CancellationToken ct)
    {
        await _mediator.Send(new CancelFoodOrderCommand(id, request?.Reason), ct);
        return NoContent();
    }

    [HttpGet("vendor/menu")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(IReadOnlyList<MenuItemResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MenuItemResponse>>> ListVendorMenu(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListVendorMenuItemsQuery(), ct);
        return Ok(result);
    }

    [HttpGet("vendor/orders")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(IReadOnlyList<FoodOrderSummaryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FoodOrderSummaryResponse>>> ListVendorOrders([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListVendorFoodOrdersQuery(page, pageSize), ct);
        return Ok(result);
    }

    [HttpPut("vendor/orders/{id:guid}/status")]
    [HttpPut("orders/{id:guid}/status")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateOrderStatus(Guid id, [FromBody] UpdateOrderStatusRequest request, CancellationToken ct)
    {
        await _mediator.Send(new UpdateFoodOrderStatusCommand(id, request.NewStatus), ct);

        // When the order is marked Ready (OutForDelivery), dispatch it to nearby
        // drivers and also send a high-priority FCM nudge so the assigned Captain
        // knows the food is ready for pickup.
        if (request.NewStatus.Equals("OutForDelivery", StringComparison.OrdinalIgnoreCase)
            || request.NewStatus.Equals("Ready", StringComparison.OrdinalIgnoreCase))
        {
            var driverIds = await _foodDispatch.DispatchFoodOrderAsync(id, ct);

            if (driverIds.Count > 0)
            {
                var driverUserIds = await _context.Drivers.AsNoTracking()
                    .Where(d => driverIds.Contains(d.Id))
                    .Select(d => d.UserId)
                    .ToListAsync(ct);

                var data = new Dictionary<string, string>
                {
                    { "type", "food_ready" },
                    { "order_id", id.ToString() },
                };

                foreach (var userId in driverUserIds)
                {
                    _ = _notifications.SendHighPriorityPushAsync(
                        userId,
                        "Food is ready",
                        "Food is ready, proceed to pickup.",
                        data,
                        ct);
                }
            }
        }

        var updatedOrder = await _context.FoodOrders.AsNoTracking()
            .FirstOrDefaultAsync(o => o.Id == id, ct);

        if (updatedOrder is not null)
        {
            _ = _hubContext.Clients.All.SendAsync("OrderUpdated", new
            {
                orderId = updatedOrder.Id,
                status = updatedOrder.Status.ToString(),
                vendorId = updatedOrder.VendorId,
            }, ct);
        }

        return NoContent();
    }
}

/// <summary>
/// Response body for HTTP 409 Conflict when menu prices have changed
/// between cart creation and checkout. The client should update the cart
/// with <see cref="LiveItemPrices"/>, show the new total, and prompt the
/// user to review before retrying checkout.
/// </summary>
public sealed record CartPriceConflictResponse(
    string Message,
    Dictionary<string, decimal> LiveItemPrices,
    decimal LiveSubTotal,
    decimal LiveTotalAmount);

public sealed record CreateFoodOrderRequest(
    Guid VendorId,
    string DeliveryAddress,
    double DeliveryLatitude,
    double DeliveryLongitude,
    PaymentMethod PaymentMethod,
    Guid? VenueId = null,
    string? Notes = null,
    IReadOnlyList<CreateFoodOrderItemDto>? Items = null,
    string? RazorpayOrderId = null,
    string? RazorpayPaymentId = null,
    string? RazorpaySignature = null);

public sealed record CreateFoodOrderItemDto(
    string Name,
    int Quantity,
    decimal UnitPrice,
    string? SpecialInstructions = null,
    IReadOnlyList<Guid>? SelectedModifierIds = null);

public sealed record CreateMenuItemRequest(
    string Name,
    decimal Price,
    string Category,
    Guid? VenueId = null,
    string? Description = null,
    string? ImageUrl = null,
    bool IsLateNight = false);

public sealed record UpdateMenuItemRequest(string Name, string? Description, string Category, decimal? NewPrice);

public sealed record CreateModifierGroupRequest(
    string Name,
    int MinSelections = 0,
    int MaxSelections = 0,
    int SortOrder = 0);

public sealed record CreateModifierRequest(
    string Name,
    decimal Price = 0m,
    bool IsAvailable = true,
    int SortOrder = 0);

public sealed record UpdateModifierRequest(
    string Name,
    decimal Price,
    bool IsAvailable);

public sealed record UpdateOrderStatusRequest(string NewStatus);

public sealed record CancelOrderRequest(string? Reason = null);
