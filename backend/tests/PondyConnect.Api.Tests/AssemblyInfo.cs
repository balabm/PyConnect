using Xunit;

// Disable parallel test execution to avoid in-memory database conflicts.
[assembly: CollectionBehavior(CollectionBehavior.CollectionPerAssembly, DisableTestParallelization = true)]
