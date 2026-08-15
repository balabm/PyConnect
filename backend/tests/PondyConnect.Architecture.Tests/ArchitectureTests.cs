namespace PondyConnect.Architecture.Tests;

using System.Reflection;
using FluentAssertions;
using NetArchTest.Rules;
using Xunit;

public sealed class ArchitectureTests
{
    private static readonly Assembly s_domain = typeof(PondyConnect.Domain.Entities.Venue).Assembly;
    private static readonly Assembly application = typeof(PondyConnect.Application.DependencyInjection).Assembly;
    private static readonly Assembly infrastructure = typeof(PondyConnect.Infrastructure.DependencyInjection).Assembly;

    [Fact]
    public void Domain_Should_Not_Depend_On_Application_Or_Infrastructure()
    {
        var result = Types.InAssembly(s_domain)
            .Should()
            .NotHaveDependencyOn("PondyConnect.Application")
            .And()
            .NotHaveDependencyOn("PondyConnect.Infrastructure")
            .GetResult();

        result.IsSuccessful.Should().BeTrue();
    }

    [Fact]
    public void Application_Should_Not_Depend_On_Infrastructure()
    {
        var result = Types.InAssembly(application)
            .Should()
            .NotHaveDependencyOn("PondyConnect.Infrastructure")
            .GetResult();

        result.IsSuccessful.Should().BeTrue();
    }

    [Fact]
    public void Infrastructure_Should_Not_Depend_On_Api()
    {
        var result = Types.InAssembly(infrastructure)
            .Should()
            .NotHaveDependencyOn("PondyConnect.Api")
            .GetResult();

        result.IsSuccessful.Should().BeTrue();
    }

    [Fact]
    public void Domain_Entity_Types_Should_Not_Be_Interfaces()
    {
        var result = Types.InNamespace("PondyConnect.Domain.Entities")
            .That()
            .AreClasses()
            .Should()
            .NotBeInterfaces()
            .GetResult();

        result.IsSuccessful.Should().BeTrue();
    }
}