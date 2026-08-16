namespace PondyConnect.Application.Features.Wallet;

/// <summary>
/// Thrown when a driver whose cash-collection wallet is suspended attempts
/// to go online. Mapped to HTTP 403 Forbidden by the exception-handling
/// middleware so the captain app can prompt the driver to settle dues.
/// </summary>
public sealed class WalletSuspendedException : Exception
{
    public const string DefaultMessage = "Wallet suspended. Settle outstanding dues to go online.";

    public WalletSuspendedException() : base(DefaultMessage)
    {
    }

    public WalletSuspendedException(string message) : base(message)
    {
    }
}
