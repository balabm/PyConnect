namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.GeoFence;
using PondyConnect.Application.Features.Vendor;

[ApiController]
[Route("api")]
public sealed class PublicController : ControllerBase
{
    private readonly IMediator _mediator;

    public PublicController(IMediator mediator) => _mediator = mediator;

    [HttpGet("flash-promos")]
    [ProducesResponseType(typeof(IReadOnlyList<FlashPromoResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FlashPromoResponse>>> ListActiveFlashPromos(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListActiveFlashPromosQuery(), ct);
        return Ok(result);
    }

    [HttpGet("service-area")]
    [ProducesResponseType(typeof(ServiceAreaResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ServiceAreaResponse>> GetServiceArea(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetServiceAreaQuery(), ct);
        return Ok(result);
    }
}
