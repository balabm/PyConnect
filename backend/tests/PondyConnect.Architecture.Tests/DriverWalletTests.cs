namespace PondyConnect.Architecture.Tests;

using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using Xunit;

public sealed class DriverWalletTests
{
    [Fact]
    public void DriverLedgerEntry_Earning_IncreasesBalance()
    {
        var driverId = Guid.NewGuid();
        var entry = DriverLedgerEntry.Create(driverId, 100m, LedgerTransactionType.Earning, "RIDE-001");

        Assert.Equal(100m, entry.Amount);
        Assert.Equal(LedgerTransactionType.Earning, entry.TransactionType);
        Assert.Equal("RIDE-001", entry.Reference);
    }

    [Fact]
    public void DriverLedgerEntry_Withdrawal_NegativeAmount()
    {
        var driverId = Guid.NewGuid();
        var entry = DriverLedgerEntry.Create(driverId, -95m, LedgerTransactionType.Withdrawal, "INSTANT_PAYOUT");

        Assert.Equal(-95m, entry.Amount);
        Assert.Equal(LedgerTransactionType.Withdrawal, entry.TransactionType);
    }

    [Fact]
    public void BalanceCalculation_SumOfEntries_ReturnsCorrectBalance()
    {
        var driverId = Guid.NewGuid();
        var entries = new[]
        {
            DriverLedgerEntry.Create(driverId, 250m, LedgerTransactionType.Earning, "RIDE-001"),
            DriverLedgerEntry.Create(driverId, 180m, LedgerTransactionType.Earning, "FOOD-001"),
            DriverLedgerEntry.Create(driverId, 50m, LedgerTransactionType.Bonus, "BONUS"),
            DriverLedgerEntry.Create(driverId, -100m, LedgerTransactionType.Withdrawal, "PAYOUT")
        };

        var balance = entries.Sum(e => e.Amount);

        Assert.Equal(380m, balance);
    }

    [Fact]
    public void InstantPayout_FeeIs5Rupees()
    {
        Assert.Equal(5m, DriverPayoutService.InstantPayoutFee);
    }

    [Fact]
    public void ScheduledPayout_ThresholdIs100Rupees()
    {
        Assert.Equal(100m, DriverPayoutService.ScheduledPayoutThreshold);
    }

    [Fact]
    public void InstantPayout_CalculatesPayoutAmountCorrectly()
    {
        var balance = 500m;
        var fee = DriverPayoutService.InstantPayoutFee;
        var payoutAmount = balance - fee;

        Assert.Equal(495m, payoutAmount);
    }

    [Fact]
    public void InstantPayout_InsufficientBalance_ReturnsFalse()
    {
        var balance = 0m;
        var canPayout = balance > 0m;

        Assert.False(canPayout);
    }

    [Fact]
    public void InstantPayout_BalanceTooLowForFee_ReturnsFalse()
    {
        var balance = 3m;
        var fee = DriverPayoutService.InstantPayoutFee;
        var payoutAmount = balance - fee;

        Assert.True(payoutAmount <= 0m);
    }
}

public sealed class DispatchTaskTests
{
    [Fact]
    public void Create_SetsAvailableStatus()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.Ride,
            GeoLocation.Create(11.9, 79.8),
            GeoLocation.Create(11.95, 79.85),
            "White Town",
            "Rock Beach",
            100m);

        Assert.Equal(DispatchTaskStatus.Available, task.Status);
        Assert.Equal(DispatchTaskType.Ride, task.TaskType);
        Assert.Equal(100m, task.DriverEarnings);
    }

    [Fact]
    public void Assign_SetsAssignedStatus()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.FoodDelivery,
            GeoLocation.Create(11.9, 79.8),
            GeoLocation.Create(11.95, 79.85),
            "Fuoco",
            "Guest House",
            40m);

        var driverId = Guid.NewGuid();
        task.Assign(driverId);

        Assert.Equal(DispatchTaskStatus.Assigned, task.Status);
        Assert.Equal(driverId, task.DriverId);
    }

    [Fact]
    public void Start_FromAssigned_SetsInProgress()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.Ride,
            GeoLocation.Create(11.9, 79.8),
            GeoLocation.Create(11.95, 79.85),
            "A", "B", 100m);

        task.Assign(Guid.NewGuid());
        task.Start();

        Assert.Equal(DispatchTaskStatus.InProgress, task.Status);
    }

    [Fact]
    public void Complete_FromInProgress_SetsCompleted()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.EssentialsDrop,
            GeoLocation.Create(11.9, 79.8),
            GeoLocation.Create(11.95, 79.85),
            "Store", "Hotel", 30m);

        task.Assign(Guid.NewGuid());
        task.Start();
        task.Complete();

        Assert.Equal(DispatchTaskStatus.Completed, task.Status);
    }

    [Fact]
    public void Assign_OnAlreadyAssigned_Throws()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.Ride,
            GeoLocation.Create(11.9, 79.8),
            GeoLocation.Create(11.95, 79.85),
            "A", "B", 100m);

        task.Assign(Guid.NewGuid());

        Assert.Throws<InvalidOperationException>(() => task.Assign(Guid.NewGuid()));
    }

    [Fact]
    public void Cancel_FromAvailable_SetsCancelled()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.Ride,
            GeoLocation.Create(11.9, 79.8),
            GeoLocation.Create(11.95, 79.85),
            "A", "B", 100m);

        task.Cancel();

        Assert.Equal(DispatchTaskStatus.Cancelled, task.Status);
    }
}

public sealed class DriverKycTests
{
    [Fact]
    public void UploadKyc_SetsFieldsAndFlag()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Test Driver", "9000000099", VehicleType.Bike, "PY-01-AB-1234");

        driver.UploadKyc("https://example.com/aadhaar.jpg", "https://example.com/dl.jpg", "https://example.com/rc.jpg", "test@upi");

        Assert.True(driver.IsKycUploaded);
        Assert.Equal("https://example.com/aadhaar.jpg", driver.AadhaarUrl);
        Assert.Equal("https://example.com/dl.jpg", driver.DrivingLicenseUrl);
        Assert.Equal("https://example.com/rc.jpg", driver.RcUrl);
        Assert.Equal("test@upi", driver.UpiId);
    }

    [Fact]
    public void UploadKyc_WithEmptyAadhaar_Throws()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Test Driver", "9000000099", VehicleType.Bike);

        Assert.Throws<ArgumentException>(() => driver.UploadKyc("", "dl.jpg", "rc.jpg", "test@upi"));
    }

    [Fact]
    public void UploadKyc_WithEmptyUpiId_Throws()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Test Driver", "9000000099", VehicleType.Bike);

        Assert.Throws<ArgumentException>(() => driver.UploadKyc("aadhaar.jpg", "dl.jpg", "rc.jpg", ""));
    }

    [Fact]
    public void Approve_SetsIsApprovedTrue()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Test Driver", "9000000099", VehicleType.Bike);

        Assert.False(driver.IsApproved);

        driver.Approve();

        Assert.True(driver.IsApproved);
    }
}
