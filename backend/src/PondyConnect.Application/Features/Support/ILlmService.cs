namespace PondyConnect.Application.Features.Support;

public sealed record LlmResponse(string Reply, bool IsCritical, string DetectedIntent);

public interface ILlmService
{
    Task<LlmResponse> GenerateResponseAsync(
        string systemPrompt,
        string userMessage,
        CancellationToken cancellationToken);
}
