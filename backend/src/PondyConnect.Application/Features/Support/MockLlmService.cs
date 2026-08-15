namespace PondyConnect.Application.Features.Support;

public sealed class MockLlmService : ILlmService
{
    private static readonly string[] s_criticalKeywords =
    [
        "accident", "broken down", "broke down", "crashed", "locked out",
        "lost", "stuck", "emergency", "help me", "hurt", "injured", "unsafe",
        "danger", "threat", "scared", "stranded"
    ];

    private static readonly string[] s_transactionalKeywords =
    [
        "refund", "cancel", "payment", "charge", "billing", "double charged",
        "wrong amount", "overcharged", "booking", "reschedule", "modify"
    ];

    public Task<LlmResponse> GenerateResponseAsync(
        string systemPrompt,
        string userMessage,
        CancellationToken cancellationToken)
    {
        var lower = userMessage.ToLowerInvariant();

        var criticalKeyword = s_criticalKeywords.FirstOrDefault(k => lower.Contains(k));
        if (criticalKeyword is not null)
        {
            return Task.FromResult(new LlmResponse(
                Reply: "I've detected this may be an emergency situation. I'm escalating this to a human operator immediately — please stay safe and wait for our team to contact you.",
                IsCritical: true,
                DetectedIntent: $"Critical: {criticalKeyword}"));
        }

        var transactionalKeyword = s_transactionalKeywords.FirstOrDefault(k => lower.Contains(k));
        if (transactionalKeyword is not null)
        {
            var reply = transactionalKeyword switch
            {
                "refund" => "I can help you with a refund request. Could you please provide your booking ID so I can look into this?",
                "cancel" => "I can help you cancel your booking. Please share your booking ID and I'll process the cancellation.",
                "payment" or "charge" or "billing" or "double charged" or "wrong amount" or "overcharged" =>
                    "I see you have a payment concern. Please share your transaction ID and I'll check the details for you.",
                "booking" or "reschedule" or "modify" =>
                    "I can help you with your booking. Could you share your booking ID and what you'd like to change?",
                _ => "I can help you with that. Could you provide more details?"
            };

            return Task.FromResult(new LlmResponse(
                Reply: reply,
                IsCritical: false,
                DetectedIntent: $"Transactional: {transactionalKeyword}"));
        }

        return Task.FromResult(new LlmResponse(
            Reply: "Thanks for reaching out! I'm here to help with any questions about PondyConnect services — rides, food, stays, transit, and more. What would you like to know?",
            IsCritical: false,
            DetectedIntent: "Info"));
    }
}
