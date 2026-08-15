namespace PondyConnect.Api.Filters;

using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Action filter that enforces liability waiver acceptance before allowing
/// access to rental or ride-hailing endpoints. Returns HTTP 403 with a
/// structured error payload when the waiver has not been accepted.
/// </summary>
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = false)]
public sealed class RequireWaiverAttribute : Attribute, IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var currentUser = context.HttpContext.RequestServices
            .GetService<ICurrentUserService>();

        if (currentUser?.UserId is not { } userId)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var dbContext = context.HttpContext.RequestServices
            .GetRequiredService<IApplicationDbContext>();

        var hasWaiver = await dbContext.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => u.HasAcceptedLiabilityWaiver)
            .FirstOrDefaultAsync(context.HttpContext.RequestAborted);

        if (!hasWaiver)
        {
            context.Result = new ObjectResult(new
            {
                error = "Liability_Waiver_Required",
                redirect = "/legal/waiver"
            })
            {
                StatusCode = StatusCodes.Status403Forbidden
            };
            return;
        }

        await next();
    }
}
