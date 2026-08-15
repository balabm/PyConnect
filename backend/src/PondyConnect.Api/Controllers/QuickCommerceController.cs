namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using PondyConnect.Application.Features.QuickCommerce;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api")]
public sealed class QuickCommerceController : ControllerBase
{
    private readonly IMediator _mediator;

    public QuickCommerceController(IMediator mediator) => _mediator = mediator;

    [HttpGet("essentials")]
    [ProducesResponseType(typeof(IReadOnlyList<ProductResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ProductResponse>>> ListProducts(
        [FromQuery] ProductCategory? category = null,
        [FromQuery] bool? lateNight = null,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListProductsQuery(category, lateNight, true), ct);
        return Ok(result);
    }

    [HttpGet("essentials/{id:guid}")]
    [ProducesResponseType(typeof(ProductResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ProductResponse>> GetProduct(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetProductQuery(id), ct);
        return Ok(result);
    }

    [HttpPost("essentials/orders")]
    [Authorize]
    [EnableRateLimiting("OrderPolicy")]
    [ProducesResponseType(typeof(ProductOrderResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<ActionResult<ProductOrderResponse>> CreateOrder([FromBody] CreateProductOrderRequest request, CancellationToken ct)
    {
        var items = request.Items?.Select(i => new CreateProductOrderItemRequest(i.ProductId, i.Quantity)).ToList()
            ?? new List<CreateProductOrderItemRequest>();
        var cmd = new CreateProductOrderCommand(
            request.DeliveryAddress,
            request.DeliveryLatitude,
            request.DeliveryLongitude,
            request.VendorId,
            items);
        var result = await _mediator.Send(cmd, ct);
        return Ok(result);
    }

    [HttpGet("essentials/orders")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<ProductOrderSummaryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ProductOrderSummaryResponse>>> ListOrders([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListUserProductOrdersQuery(page, pageSize), ct);
        return Ok(result);
    }

    [HttpPost("essentials/suggestions")]
    [ProducesResponseType(typeof(IReadOnlyList<ProductResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ProductResponse>>> GetSuggestions([FromBody] GetSuggestionsRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetBundleSuggestionsQuery(request.ProductIds), ct);
        return Ok(result);
    }

    [HttpPost("vendor/essentials")]
    [Authorize(Roles = "Vendor")]
    [ProducesResponseType(typeof(ProductResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ProductResponse>> CreateProduct([FromBody] CreateProductRequest request, CancellationToken ct)
    {
        var cmd = new CreateProductCommand(
            request.Name,
            request.Price,
            request.Category,
            request.SubCategory,
            request.StockCount,
            request.VendorId,
            request.Description,
            request.Brand,
            request.ImageUrl,
            request.IsLateNightEssential);
        var result = await _mediator.Send(cmd, ct);
        return Ok(result);
    }
}

public sealed record CreateProductOrderRequest(
    string DeliveryAddress,
    double DeliveryLatitude,
    double DeliveryLongitude,
    Guid? VendorId = null,
    IReadOnlyList<CreateProductOrderItemDto>? Items = null);

public sealed record CreateProductOrderItemDto(Guid ProductId, int Quantity);

public sealed record GetSuggestionsRequest(IReadOnlyList<Guid> ProductIds);

public sealed record CreateProductRequest(
    string Name,
    decimal Price,
    ProductCategory Category,
    string SubCategory,
    int StockCount = 0,
    Guid? VendorId = null,
    string? Description = null,
    string? Brand = null,
    string? ImageUrl = null,
    bool IsLateNightEssential = false);
