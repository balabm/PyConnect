namespace PondyConnect.Api.Services;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.Invoicing;

/// <summary>
/// Background service that runs on the 1st of every month at 12:01 AM
/// to generate GST tax invoices for all vendors. Scans the previous
/// month's commission ledger entries and generates compliant PDFs.
/// </summary>
public sealed class MonthlyInvoiceWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<MonthlyInvoiceWorker> _logger;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(1);

    private DateOnly? _lastRunDate;

    public MonthlyInvoiceWorker(IServiceProvider services, ILogger<MonthlyInvoiceWorker> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(CheckInterval, stoppingToken);

                var now = DateTimeOffset.UtcNow;
                var today = DateOnly.FromDateTime(now.Date);

                // Run on the 1st of each month at or after 00:01 UTC
                if (today.Day == 1 && now.TimeOfDay >= TimeSpan.FromMinutes(1) && _lastRunDate != today)
                {
                    _lastRunDate = today;

                    // Generate invoices for the previous month
                    var (year, month) = today.Year == 1 && today.Month == 1
                        ? (today.Year - 1, 12)
                        : (today.Year, today.Month - 1);

                    if (month == 0)
                    {
                        year--;
                        month = 12;
                    }

                    using var scope = _services.CreateScope();
                    var invoiceService = scope.ServiceProvider.GetRequiredService<InvoiceService>();

                    _logger.LogInformation("Starting monthly invoice generation for {Year}-{Month:D2}", year, month);

                    var invoices = await invoiceService.GenerateMonthlyInvoicesAsync(year, month, stoppingToken);

                    _logger.LogInformation("Monthly invoice generation complete: {Count} invoices for {Year}-{Month:D2}", invoices.Count, year, month);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during monthly invoice generation");
            }
        }
    }
}
