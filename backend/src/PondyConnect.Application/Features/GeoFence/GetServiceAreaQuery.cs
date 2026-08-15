namespace PondyConnect.Application.Features.GeoFence;

using MediatR;

public sealed record GetServiceAreaQuery() : IRequest<ServiceAreaResponse>;

public sealed record ServiceAreaResponse(double CenterLatitude, double CenterLongitude, double RadiusKm);

public sealed class GetServiceAreaHandler : IRequestHandler<GetServiceAreaQuery, ServiceAreaResponse>
{
    private readonly ServiceAreaValidator _validator;

    public GetServiceAreaHandler(ServiceAreaValidator validator) => _validator = validator;

    public Task<ServiceAreaResponse> Handle(GetServiceAreaQuery request, CancellationToken cancellationToken)
    {
        return Task.FromResult(new ServiceAreaResponse(
            _validator.Center.Latitude,
            _validator.Center.Longitude,
            _validator.RadiusKm));
    }
}
