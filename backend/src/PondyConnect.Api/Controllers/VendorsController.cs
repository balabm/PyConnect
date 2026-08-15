namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api/vendors")]
public sealed class VendorsController : ControllerBase
{
    private readonly IMediator _mediator;

    public VendorsController(IMediator mediator)
    {
        _mediator = mediator;
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