namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/vendors")]
public sealed class VendorsController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly RiskInterceptor? _riskInterceptor;
    private readonly ICurrentUserService? _currentUser;

    public VendorsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    public VendorsController(
        IMediator mediator,
        RiskInterceptor riskInterceptor,
        ICurrentUserService currentUser) : this(mediator)
    {
        _riskInterceptor = riskInterceptor;
        _currentUser = currentUser;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<VendorResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VendorResponse>>> List(
        [FromQuery] VendorCategory? category = null,
        [FromQuery] bool foodVendorsOnly = false,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default)
    {
        // Shadow-ban intercept: shadow-banned users see empty vendor list
        if (_riskInterceptor is not null && _currentUser is not null)
        {
            if (await _riskInterceptor.IsShadowBannedAsync(_currentUser.UserId, cancellationToken))
                return Ok(Array.Empty<VendorResponse>());
        }

        // Clamp pagination parameters to reasonable bounds
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var vendors = await _mediator.Send(new ListVendorsQuery(category, FoodVendorsOnly: foodVendorsOnly), cancellationToken);

        // Apply pagination
        var paged = vendors
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();

        return Ok(paged);
    }
}