namespace PondyConnect.Architecture.Tests;

using FluentAssertions;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class PaymentEntityTests
{
    [Fact]
    public void CreateForServiceBooking_SetsAmountAndBookingId()
    {
        var bookingId = Guid.NewGuid();
        var payment = Payment.CreateForServiceBooking(bookingId, 500m);

        payment.ServiceBookingId.Should().Be(bookingId);
        payment.Amount.Should().Be(500m);
        payment.Status.Should().Be(PaymentStatus.Unpaid);
    }

    [Fact]
    public void CreateForFoodOrder_SetsFoodOrderIdAndAmount()
    {
        var orderId = Guid.NewGuid();
        var payment = Payment.CreateForFoodOrder(orderId, 250m);

        payment.FoodOrderId.Should().Be(orderId);
        payment.Amount.Should().Be(250m);
    }

    [Fact]
    public void CreateForTransitTrip_SetsTransitTripId()
    {
        var tripId = Guid.NewGuid();
        var payment = Payment.CreateForTransitTrip(tripId, 120m);

        payment.TransitTripId.Should().Be(tripId);
        payment.Amount.Should().Be(120m);
    }

    [Fact]
    public void CreateForLuggageDropOff_SetsLuggageDropOffId()
    {
        var dropOffId = Guid.NewGuid();
        var payment = Payment.CreateForLuggageDropOff(dropOffId, 80m);

        payment.LuggageDropOffId.Should().Be(dropOffId);
        payment.Amount.Should().Be(80m);
    }

    [Fact]
    public void CreateForScooterRental_SetsScooterRentalId()
    {
        var rentalId = Guid.NewGuid();
        var payment = Payment.CreateForScooterRental(rentalId, 300m);

        payment.ScooterRentalId.Should().Be(rentalId);
        payment.Amount.Should().Be(300m);
    }

    [Fact]
    public void MarkCaptured_SetsStatusAndProviderPaymentId()
    {
        var payment = Payment.CreateForServiceBooking(Guid.NewGuid(), 100m);
        payment.MarkProviderOrderCreated("order-123");
        payment.MarkCaptured("pay-456");

        payment.Status.Should().Be(PaymentStatus.Captured);
        payment.ProviderPaymentId.Should().Be("pay-456");
        payment.CapturedAt.Should().HaveValue();
    }

    [Fact]
    public void MarkFailed_SetsStatusAndReason()
    {
        var payment = Payment.CreateForServiceBooking(Guid.NewGuid(), 100m);
        payment.MarkFailed("Insufficient funds");

        payment.Status.Should().Be(PaymentStatus.Failed);
        payment.FailureReason.Should().Be("Insufficient funds");
    }

    [Fact]
    public void MarkRefunded_OnlyWorksOnCaptured_ThrowsOtherwise()
    {
        var unpaidPayment = Payment.CreateForServiceBooking(Guid.NewGuid(), 100m);
        var act = () => unpaidPayment.MarkRefunded();
        act.Should().Throw<InvalidOperationException>();

        var capturedPayment = Payment.CreateForServiceBooking(Guid.NewGuid(), 100m);
        capturedPayment.MarkProviderOrderCreated("order-1");
        capturedPayment.MarkCaptured("pay-1");
        capturedPayment.MarkRefunded();
        capturedPayment.Status.Should().Be(PaymentStatus.Refunded);
        capturedPayment.RefundedAt.Should().NotBeNull();
    }
}

public sealed class PaymentSettlementEntityTests
{
    [Fact]
    public void Create_WithFoodOrderId_SetsFoodOrderId()
    {
        var settlement = PaymentSettlement.Create(
            Guid.NewGuid(), 500m, 500m, 0m, 0m, foodOrderId: Guid.NewGuid());

        settlement.FoodOrderId.Should().NotBeNull();
        settlement.GrossAmount.Should().Be(500m);
        settlement.VendorPayout.Should().Be(500m);
        settlement.PlatformFee.Should().Be(0m);
    }

    [Fact]
    public void Create_WithServiceBookingId_SetsServiceBookingId()
    {
        var bookingId = Guid.NewGuid();
        var settlement = PaymentSettlement.Create(
            Guid.NewGuid(), 300m, 300m, 0m, 0m, serviceBookingId: bookingId);

        settlement.ServiceBookingId.Should().Be(bookingId);
    }

    [Fact]
    public void Create_WithNegativeAmount_Throws()
    {
        var act = () => PaymentSettlement.Create(Guid.NewGuid(), -100m, 0m, 0m, 0m);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void Create_SetsStatusToProcessed()
    {
        var settlement = PaymentSettlement.Create(Guid.NewGuid(), 100m, 80m, 15m, 5m);

        settlement.SettlementStatus.Should().Be(SettlementStatus.Processed);
        settlement.ProcessedAt.Should().HaveValue();
    }

    [Fact]
    public void Reverse_SetsStatusToReversed()
    {
        var settlement = PaymentSettlement.Create(Guid.NewGuid(), 100m, 80m, 15m, 5m);
        settlement.Reverse();

        settlement.SettlementStatus.Should().Be(SettlementStatus.Reversed);
    }
}

public sealed class FoodOrderEntityTests
{
    [Fact]
    public void Create_SetsDefaultValues_PlacedStatus()
    {
        var order = FoodOrder.Create(
            Guid.NewGuid(), Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), 280m, 30m, 0m, PaymentMethod.Cash);

        order.Status.Should().Be(FoodOrderStatus.Placed);
        order.Currency.Should().Be("INR");
        order.PlacedAt.Should().BeCloseTo(DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
        order.DeliveredAt.Should().BeNull();
    }

    [Fact]
    public void Create_VendorPayoutEqualsSubTotal_PlatformFeeTwo()
    {
        var order = FoodOrder.Create(
            Guid.NewGuid(), Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), 280m, 30m, 0m, PaymentMethod.Cash);

        order.VendorPayout.Should().Be(order.SubTotal);
        order.PlatformFee.Should().Be(2m);
        order.TotalAmount.Should().Be(280m + 30m + 2m);
    }

    [Fact]
    public void AddItem_RecalculatesSubTotalAndTotal()
    {
        var order = FoodOrder.Create(
            Guid.NewGuid(), Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), 0m, 30m, 0m, PaymentMethod.Cash);

        order.AddItem("Pizza", 2, 150m);

        order.SubTotal.Should().Be(300m);
        order.TotalAmount.Should().Be(332m);
        order.Items.Should().HaveCount(1);
    }

    [Fact]
    public void Accept_FromPlaced_SetsAccepted()
    {
        var order = CreateDefaultFoodOrder();
        order.Accept();
        order.Status.Should().Be(FoodOrderStatus.Accepted);
    }

    [Fact]
    public void StartPreparing_FromAccepted_SetsPreparing()
    {
        var order = CreateDefaultFoodOrder();
        order.Accept();
        order.StartPreparing();
        order.Status.Should().Be(FoodOrderStatus.Preparing);
    }

    [Fact]
    public void Dispatch_FromPreparing_SetsOutForDelivery()
    {
        var order = CreateDefaultFoodOrder();
        order.Accept();
        order.StartPreparing();
        order.Dispatch();
        order.Status.Should().Be(FoodOrderStatus.OutForDelivery);
    }

    [Fact]
    public void Deliver_FromOutForDelivery_SetsDelivered()
    {
        var order = CreateDefaultFoodOrder();
        order.Accept();
        order.StartPreparing();
        order.Dispatch();
        order.Deliver();
        order.Status.Should().Be(FoodOrderStatus.Delivered);
        order.DeliveredAt.Should().HaveValue();
    }

    [Fact]
    public void Cancel_AlreadyDelivered_Throws()
    {
        var order = CreateDefaultFoodOrder();
        order.Accept();
        order.StartPreparing();
        order.Dispatch();
        order.Deliver();

        var act = () => order.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    private static FoodOrder CreateDefaultFoodOrder()
        => FoodOrder.Create(
            Guid.NewGuid(), Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), 280m, 30m, 0m, PaymentMethod.Cash);
}

public sealed class ServiceBookingEntityTests
{
    [Fact]
    public void Complete_OnCancelledBooking_Throws()
    {
        var booking = CreateDefaultBooking();
        booking.Cancel();

        var act = () => booking.Complete();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Complete_OnPendingBooking_SetsCompleted()
    {
        var booking = CreateDefaultBooking();
        booking.Complete();

        booking.Status.Should().Be(BookingStatus.Completed);
        booking.CompletedAt.Should().HaveValue();
    }

    [Fact]
    public void CheckIn_OnNonConfirmed_Throws()
    {
        var booking = CreateDefaultBooking();

        var act = () => booking.CheckIn();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Confirm_OnCancelled_Throws()
    {
        var booking = CreateDefaultBooking();
        booking.Cancel();

        var act = () => booking.Confirm();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_SetsCancelledStatus()
    {
        var booking = CreateDefaultBooking();
        booking.Cancel();

        booking.Status.Should().Be(BookingStatus.Cancelled);
    }

    [Fact]
    public void IssuePassToken_SetsPassToken()
    {
        var booking = CreateDefaultBooking();
        booking.IssuePassToken("token-abc-123");

        booking.PassToken.Should().Be("token-abc-123");
    }

    [Fact]
    public void RecordPayment_SetsPaymentStatusAndReference()
    {
        var booking = CreateDefaultBooking();
        booking.RecordPayment(PaymentStatus.Captured, "ref-001");

        booking.PaymentStatus.Should().Be(PaymentStatus.Captured);
        booking.PaymentReference.Should().Be("ref-001");
    }

    private static ServiceBooking CreateDefaultBooking()
        => ServiceBooking.Create(
            Guid.NewGuid(),
            ServiceType.Nightlife,
            DateTimeOffset.UtcNow.AddDays(1),
            amount: 500m);
}

public sealed class VenueEntityTests
{
    [Fact]
    public void IncreaseOccupancy_AtFullCapacity_Throws()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 50);
        venue.IncreaseOccupancy(50);

        var act = () => venue.IncreaseOccupancy(1);
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void DecreaseOccupancy_BelowZero_Throws()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 50);

        var act = () => venue.DecreaseOccupancy(1);
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void IncrementCheckedIn_ExceedsCurrentCapacity_Throws()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 50);
        venue.IncreaseOccupancy(5);

        var act = () => venue.IncrementCheckedIn(6);
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void DecrementCheckedIn_BelowZero_Throws()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 50);

        var act = () => venue.DecrementCheckedIn(1);
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void ForceSoldOut_SetsInactiveAndFullCapacity()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 50);
        venue.ForceSoldOut();

        venue.IsActive.Should().BeFalse();
        venue.CurrentCapacity.Should().Be(50);
    }

    [Fact]
    public void Reopen_ResetsCapacityAndCheckedIn()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 50);
        venue.IncreaseOccupancy(30);
        venue.IncrementCheckedIn(10);
        venue.ForceSoldOut();

        venue.Reopen();

        venue.IsActive.Should().BeTrue();
        venue.CurrentCapacity.Should().Be(0);
        venue.CheckedInCount.Should().Be(0);
    }

    [Fact]
    public void SetMaxCapacity_BelowCurrentOccupancy_Throws()
    {
        var venue = Venue.Create("Test", VenueCategory.Pub, GeoLocation.Create(11.93, 79.83), maxCapacity: 100);
        venue.IncreaseOccupancy(50);

        var act = () => venue.SetMaxCapacity(40);
        act.Should().Throw<InvalidOperationException>();
    }
}

public sealed class RideRequestEntityTests
{
    [Fact]
    public void Create_WithStandardFare_SetsFareAndPlatformFee()
    {
        var ride = RideRequest.Create(
            Guid.NewGuid(),
            GeoLocation.Create(11.93, 79.83),
            "White Town",
            GeoLocation.Create(11.95, 79.85),
            "Rock Beach",
            distanceKm: 5.0,
            estimatedDurationMin: 15,
            VehicleType.Bike,
            fare: 50m,
            PaymentMethod.Cash);

        ride.Fare.Should().Be(50m);
        ride.PlatformBookingFee.Should().Be(15m);
        ride.TotalAmount.Should().Be(65m);
        ride.Status.Should().Be(RideStatus.Requested);
        ride.IsSos.Should().BeFalse();
    }

    [Fact]
    public void Create_WithSos_SetsSosPricingAndNoPlatformFee()
    {
        var ride = RideRequest.Create(
            Guid.NewGuid(),
            GeoLocation.Create(11.93, 79.83),
            "White Town",
            GeoLocation.Create(11.95, 79.85),
            "Rock Beach",
            distanceKm: 5.0,
            estimatedDurationMin: 15,
            VehicleType.Bike,
            fare: 100m,
            PaymentMethod.Cash,
            isSos: true,
            sosDriverPayout: 220m,
            platformEmergencyFee: 30m);

        ride.IsSos.Should().BeTrue();
        ride.Fare.Should().Be(100m);
        ride.SosDriverPayout.Should().Be(220m);
        ride.PlatformEmergencyFee.Should().Be(30m);
        ride.PlatformBookingFee.Should().Be(30m);
        ride.TotalAmount.Should().Be(100m);
    }

    [Fact]
    public void Accept_FromRequested_SetsAccepted()
    {
        var ride = CreateDefaultRide();
        var driverId = Guid.NewGuid();
        ride.Accept(driverId);

        ride.Status.Should().Be(RideStatus.Accepted);
        ride.DriverId.Should().Be(driverId);
        ride.AcceptedAt.Should().HaveValue();
    }

    [Fact]
    public void StartRide_FromAccepted_SetsEnRoute()
    {
        var ride = CreateDefaultRide();
        ride.Accept(Guid.NewGuid());
        ride.StartRide();

        ride.Status.Should().Be(RideStatus.EnRoute);
    }

    [Fact]
    public void Complete_FromEnRoute_SetsCompleted()
    {
        var ride = CreateDefaultRide();
        ride.Accept(Guid.NewGuid());
        ride.StartRide();
        ride.Complete();

        ride.Status.Should().Be(RideStatus.Completed);
        ride.CompletedAt.Should().HaveValue();
    }

    [Fact]
    public void Complete_OnCancelled_Throws()
    {
        var ride = CreateDefaultRide();
        ride.Cancel();

        var act = () => ride.Complete();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_OnCompleted_Throws()
    {
        var ride = CreateDefaultRide();
        ride.Accept(Guid.NewGuid());
        ride.StartRide();
        ride.Complete();

        var act = () => ride.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_FromRequested_SetsCancelledWithReason()
    {
        var ride = CreateDefaultRide();
        ride.Cancel("Changed mind");

        ride.Status.Should().Be(RideStatus.Cancelled);
        ride.CancelReason.Should().Be("Changed mind");
        ride.CancelledAt.Should().HaveValue();
    }

    private static RideRequest CreateDefaultRide()
        => RideRequest.Create(
            Guid.NewGuid(),
            GeoLocation.Create(11.93, 79.83),
            "White Town",
            GeoLocation.Create(11.95, 79.85),
            "Rock Beach",
            distanceKm: 5.0,
            estimatedDurationMin: 15,
            VehicleType.Bike,
            fare: 50m,
            PaymentMethod.Cash);
}

public sealed class RideRequestStateMachineTests
{
    [Fact]
    public void StartSearching_FromRequested_SetsSearching()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();

        ride.Status.Should().Be(RideStatus.Searching);
    }

    [Fact]
    public void AssignDriver_FromSearching_SetsDriverAssignedWithOtp()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        var driverId = Guid.NewGuid();
        ride.AssignDriver(driverId, "1234");

        ride.Status.Should().Be(RideStatus.DriverAssigned);
        ride.DriverId.Should().Be(driverId);
        ride.OtpCode.Should().Be("1234");
        ride.DriverAssignedAt.Should().HaveValue();
    }

    [Fact]
    public void ArriveAtPickup_FromDriverAssigned_SetsArrivedAtPickup()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.ArriveAtPickup();

        ride.Status.Should().Be(RideStatus.ArrivedAtPickup);
        ride.ArrivedAtPickupAt.Should().HaveValue();
    }

    [Fact]
    public void VerifyOtpAndStart_WithCorrectOtp_SetsEnRoute()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.VerifyOtpAndStart("1234");

        ride.Status.Should().Be(RideStatus.EnRoute);
        ride.OtpVerifiedAt.Should().HaveValue();
        ride.StartedAt.Should().HaveValue();
    }

    [Fact]
    public void VerifyOtpAndStart_WithWrongOtp_Throws()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");

        var act = () => ride.VerifyOtpAndStart("9999");
        act.Should().Throw<InvalidOperationException>().WithMessage("*Invalid OTP*");
    }

    [Fact]
    public void CompleteWithMetrics_FromEnRoute_SetsCompletedWithMetrics()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.VerifyOtpAndStart("1234");
        ride.CompleteWithMetrics(actualDistanceKm: 5.2, actualDurationMin: 14);

        ride.Status.Should().Be(RideStatus.Completed);
        ride.ActualDistanceKm.Should().Be(5.2);
        ride.ActualDurationMin.Should().Be(14);
        ride.CompletedAt.Should().HaveValue();
    }

    [Fact]
    public void CancelByRider_BeforeDriverAssigned_NoFee()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.CancelByRider("Changed mind");

        ride.Status.Should().Be(RideStatus.Cancelled);
        ride.CancelledBy.Should().Be(CancelledBy.Rider);
        ride.CancellationFee.Should().Be(0m);
    }

    [Fact]
    public void CancelByDriver_FromDriverAssigned_SetsDriverCancelled()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.CancelByDriver("Emergency");

        ride.Status.Should().Be(RideStatus.DriverCancelled);
        ride.CancelledBy.Should().Be(CancelledBy.Driver);
    }

    [Fact]
    public void ReassignForDispatch_FromDriverCancelled_ResetsToSearching()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.CancelByDriver("Emergency");
        ride.ReassignForDispatch();

        ride.Status.Should().Be(RideStatus.Searching);
        ride.DriverId.Should().BeNull();
        ride.OtpCode.Should().BeNull();
    }

    [Fact]
    public void RateByRider_OnCompletedRide_SetsRating()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.VerifyOtpAndStart("1234");
        ride.CompleteWithMetrics(5.0, 15);
        ride.RateByRider(5, "Great driver");

        ride.RatingByRider.Should().Be(5);
        ride.RiderFeedback.Should().Be("Great driver");
    }

    [Fact]
    public void RateByRider_WithInvalidRating_Throws()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.AssignDriver(Guid.NewGuid(), "1234");
        ride.VerifyOtpAndStart("1234");
        ride.CompleteWithMetrics(5.0, 15);

        var act = () => ride.RateByRider(6);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void EnableTripSharing_GeneratesToken()
    {
        var ride = CreateDefaultRide();
        var token = ride.EnableTripSharing();

        token.Should().NotBeEmpty();
        ride.TripShareToken.Should().Be(token);
    }

    [Fact]
    public void EnableTripSharing_CalledTwice_ReturnsSameToken()
    {
        var ride = CreateDefaultRide();
        var token1 = ride.EnableTripSharing();
        var token2 = ride.EnableTripSharing();

        token2.Should().Be(token1);
    }

    [Fact]
    public void MarkNoDriversAvailable_FromSearching_SetsNoDriversAvailable()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.MarkNoDriversAvailable();

        ride.Status.Should().Be(RideStatus.NoDriversAvailable);
    }

    [Fact]
    public void CancelBySystem_SetsSystemCancelledWithNoFee()
    {
        var ride = CreateDefaultRide();
        ride.StartSearching();
        ride.CancelBySystem("No drivers available");

        ride.Status.Should().Be(RideStatus.Cancelled);
        ride.CancelledBy.Should().Be(CancelledBy.System);
        ride.CancellationFee.Should().Be(0m);
    }

    private static RideRequest CreateDefaultRide()
        => RideRequest.Create(
            Guid.NewGuid(),
            GeoLocation.Create(11.93, 79.83),
            "White Town",
            GeoLocation.Create(11.95, 79.85),
            "Rock Beach",
            distanceKm: 5.0,
            estimatedDurationMin: 15,
            VehicleType.Bike,
            fare: 50m,
            PaymentMethod.Cash);
}

public sealed class DriverRideLifecycleTests
{
    [Fact]
    public void GoOnline_WhileOnRide_Throws()
    {
        var driver = CreateDefaultDriver();
        driver.Approve();
        driver.GoOnline();
        driver.StartRide(Guid.NewGuid());

        var act = () => driver.GoOnline();
        act.Should().Throw<InvalidOperationException>().WithMessage("*active ride*");
    }

    [Fact]
    public void StartRide_SetsIsOnRideAndCurrentRideId()
    {
        var driver = CreateDefaultDriver();
        var rideId = Guid.NewGuid();
        driver.StartRide(rideId);

        driver.IsOnRide.Should().BeTrue();
        driver.CurrentRideId.Should().Be(rideId);
    }

    [Fact]
    public void StartRide_AlreadyOnRide_Throws()
    {
        var driver = CreateDefaultDriver();
        driver.StartRide(Guid.NewGuid());

        var act = () => driver.StartRide(Guid.NewGuid());
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void EndRide_IncrementsTotalRides()
    {
        var driver = CreateDefaultDriver();
        driver.StartRide(Guid.NewGuid());
        driver.EndRide();

        driver.IsOnRide.Should().BeFalse();
        driver.TotalRides.Should().Be(1);
    }

    [Fact]
    public void RecordOfferResult_UpdatesAcceptanceRate()
    {
        var driver = CreateDefaultDriver();
        driver.RecordOfferResult(true);
        driver.RecordOfferResult(false);
        driver.RecordOfferResult(true);

        driver.TotalOffers.Should().Be(3);
        driver.TotalAccepted.Should().Be(2);
        driver.AcceptanceRate.Should().BeApproximately(2.0 / 3.0, 0.001);
    }

    [Fact]
    public void UpdateRating_UsesWeightedAverage()
    {
        var driver = CreateDefaultDriver();
        driver.UpdateRating(5);
        driver.UpdateRating(3);
        driver.UpdateRating(4);

        driver.TotalRatings.Should().Be(3);
        driver.Rating.Should().BeApproximately((5.0 + 3.0 + 4.0) / 3.0, 0.01);
    }

    [Fact]
    public void SetEmergencyContact_SetsNameAndPhone()
    {
        var driver = CreateDefaultDriver();
        driver.SetEmergencyContact("Jane Doe", "9876543210");

        driver.EmergencyContactName.Should().Be("Jane Doe");
        driver.EmergencyContactPhone.Should().Be("9876543210");
    }

    private static Driver CreateDefaultDriver()
        => Driver.Create(Guid.NewGuid(), "Test Driver", "9000000000", VehicleType.Bike, "TN01AB1234");
}

public sealed class ScooterRentalEntityTests
{
    [Fact]
    public void Create_CalculatesTotalAmountFromHoursAndRate()
    {
        var start = DateTimeOffset.UtcNow.AddMinutes(10);
        var end = start.AddHours(4);

        var rental = ScooterRental.Create(
            Guid.NewGuid(), Guid.NewGuid(), "Honda Activa",
            start, end, ratePerHour: 75m);

        rental.TotalAmount.Should().Be(300m);
        rental.Status.Should().Be(RentalStatus.Reserved);
    }

    [Fact]
    public void StartRental_FromReserved_SetsActive()
    {
        var rental = CreateDefaultRental();
        rental.StartRental();

        rental.Status.Should().Be(RentalStatus.Active);
    }

    [Fact]
    public void Return_FromActive_SetsReturned()
    {
        var rental = CreateDefaultRental();
        rental.StartRental();
        rental.Return();

        rental.Status.Should().Be(RentalStatus.Returned);
    }

    [Fact]
    public void Cancel_OnReturned_Throws()
    {
        var rental = CreateDefaultRental();
        rental.StartRental();
        rental.Return();

        var act = () => rental.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_OnAlreadyCancelled_Throws()
    {
        var rental = CreateDefaultRental();
        rental.Cancel();

        var act = () => rental.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void RecordPayment_SetsPaymentStatusAndReference()
    {
        var rental = CreateDefaultRental();
        rental.RecordPayment(PaymentStatus.Captured, "pay-ref-001");

        rental.PaymentStatus.Should().Be(PaymentStatus.Captured);
        rental.PaymentReference.Should().Be("pay-ref-001");
    }

    private static ScooterRental CreateDefaultRental()
    {
        var start = DateTimeOffset.UtcNow.AddMinutes(10);
        var end = start.AddHours(2);
        return ScooterRental.Create(
            Guid.NewGuid(), Guid.NewGuid(), "Honda Activa",
            start, end, ratePerHour: 75m);
    }
}

public sealed class LuggageDropOffEntityTests
{
    [Fact]
    public void Create_CalculatesTotalAmountFromRateAndBags()
    {
        var now = DateTimeOffset.UtcNow.AddMinutes(10);

        var dropOff = LuggageDropOff.Create(
            Guid.NewGuid(), Guid.NewGuid(), now, now,
            bagCount: 3, ratePerHour: 20m);

        dropOff.TotalAmount.Should().Be(60m);
        dropOff.Status.Should().Be(LuggageStatus.Reserved);
    }

    [Fact]
    public void MarkDropped_FromReserved_SetsDropped()
    {
        var dropOff = CreateDefaultDropOff();
        dropOff.MarkDropped();

        dropOff.Status.Should().Be(LuggageStatus.Dropped);
    }

    [Fact]
    public void MarkCollected_FromDropped_SetsCollectedAndPickedUpAt()
    {
        var dropOff = CreateDefaultDropOff();
        dropOff.MarkDropped();
        dropOff.MarkCollected();

        dropOff.Status.Should().Be(LuggageStatus.Collected);
        dropOff.PickedUpAt.Should().HaveValue();
    }

    [Fact]
    public void Cancel_OnCollected_Throws()
    {
        var dropOff = CreateDefaultDropOff();
        dropOff.MarkDropped();
        dropOff.MarkCollected();

        var act = () => dropOff.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_OnAlreadyCancelled_Throws()
    {
        var dropOff = CreateDefaultDropOff();
        dropOff.Cancel();

        var act = () => dropOff.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void RecordPayment_SetsPaymentStatusAndReference()
    {
        var dropOff = CreateDefaultDropOff();
        dropOff.RecordPayment(PaymentStatus.Captured, "luggage-pay-001");

        dropOff.PaymentStatus.Should().Be(PaymentStatus.Captured);
        dropOff.PaymentReference.Should().Be("luggage-pay-001");
    }

    private static LuggageDropOff CreateDefaultDropOff()
    {
        var now = DateTimeOffset.UtcNow.AddMinutes(10);
        return LuggageDropOff.Create(
            Guid.NewGuid(), Guid.NewGuid(), now, now,
            bagCount: 2, ratePerHour: 20m);
    }
}

public sealed class TransitTripEntityTests
{
    [Fact]
    public void Create_SetsDefaults()
    {
        var trip = CreateDefaultTrip();

        trip.Status.Should().Be(TransitStatus.Requested);
        trip.PartySize.Should().Be(2);
        trip.Price.Should().Be(150m);
    }

    [Fact]
    public void Assign_FromRequested_SetsAssignedAndVendorId()
    {
        var trip = CreateDefaultTrip();
        var vendorId = Guid.NewGuid();
        trip.Assign(vendorId);

        trip.Status.Should().Be(TransitStatus.Assigned);
        trip.VendorId.Should().Be(vendorId);
        trip.AssignedAt.Should().HaveValue();
    }

    [Fact]
    public void Start_FromAssigned_SetsEnRoute()
    {
        var trip = CreateDefaultTrip();
        trip.Assign(Guid.NewGuid());
        trip.Start();

        trip.Status.Should().Be(TransitStatus.EnRoute);
        trip.StartedAt.Should().HaveValue();
    }

    [Fact]
    public void Complete_FromEnRoute_SetsCompleted()
    {
        var trip = CreateDefaultTrip();
        trip.Assign(Guid.NewGuid());
        trip.Start();
        trip.Complete();

        trip.Status.Should().Be(TransitStatus.Completed);
        trip.CompletedAt.Should().HaveValue();
    }

    [Fact]
    public void Cancel_OnCompleted_Throws()
    {
        var trip = CreateDefaultTrip();
        trip.Assign(Guid.NewGuid());
        trip.Start();
        trip.Complete();

        var act = () => trip.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_OnAlreadyCancelled_Throws()
    {
        var trip = CreateDefaultTrip();
        trip.Cancel();

        var act = () => trip.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void RecordPayment_SetsPaymentStatusAndReference()
    {
        var trip = CreateDefaultTrip();
        trip.RecordPayment(PaymentStatus.Captured, "transit-pay-001");

        trip.PaymentStatus.Should().Be(PaymentStatus.Captured);
        trip.PaymentReference.Should().Be("transit-pay-001");
    }

    private static TransitTrip CreateDefaultTrip()
        => TransitTrip.Create(
            Guid.NewGuid(), Guid.NewGuid(), "Chennai", "Bus",
            DateTimeOffset.UtcNow.AddHours(2), partySize: 2, price: 150m);
}

public sealed class BundleBookingEntityTests
{
    [Fact]
    public void Create_WithValidPrices_SetsProperties()
    {
        var bundle = BundleBooking.Create(
            Guid.NewGuid(), "Long Weekend Pass",
            totalPrice: 1000m, discountedPrice: 800m);

        bundle.TotalPrice.Should().Be(1000m);
        bundle.DiscountedPrice.Should().Be(800m);
        bundle.Status.Should().Be(BundleStatus.Active);
    }

    [Fact]
    public void Create_WithDiscountedPriceGreaterThanTotal_Throws()
    {
        var act = () => BundleBooking.Create(
            Guid.NewGuid(), "Bad Bundle",
            totalPrice: 500m, discountedPrice: 600m);
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void AddItem_AddsToItemsList()
    {
        var bundle = BundleBooking.Create(Guid.NewGuid(), "Pass", 1000m, 800m);
        var item = BundleItem.Create(bundle.Id, "Spa Session", 300m);

        bundle.AddItem(item);

        bundle.Items.Should().HaveCount(1);
        bundle.Items[0].ServiceName.Should().Be("Spa Session");
    }

    [Fact]
    public void MarkFullyRedeemed_SetsStatus()
    {
        var bundle = BundleBooking.Create(Guid.NewGuid(), "Pass", 1000m, 800m);
        bundle.MarkFullyRedeemed();

        bundle.Status.Should().Be(BundleStatus.FullyRedeemed);
    }

    [Fact]
    public void IssuePass_SetsPassToken()
    {
        var bundle = BundleBooking.Create(Guid.NewGuid(), "Pass", 1000m, 800m);
        bundle.IssuePass("bundle-token-abc");

        bundle.PassToken.Should().Be("bundle-token-abc");
    }
}

public sealed class BundleItemEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var item = BundleItem.Create(Guid.NewGuid(), "Sunset Cruise", 500m);

        item.ServiceName.Should().Be("Sunset Cruise");
        item.OriginalPrice.Should().Be(500m);
        item.IsRedeemed.Should().BeFalse();
    }

    [Fact]
    public void Redeem_SetsIsRedeemedAndRedeemedAt()
    {
        var item = BundleItem.Create(Guid.NewGuid(), "Sunset Cruise", 500m);
        item.Redeem("booking-ref-001");

        item.IsRedeemed.Should().BeTrue();
        item.ServiceReferenceId.Should().Be("booking-ref-001");
        item.RedeemedAt.Should().HaveValue();
    }
}

public sealed class ProductEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var product = Product.Create(
            "Bottled Water", 20m, ProductCategory.Misc,
            "Beverages", stockCount: 100);

        product.Name.Should().Be("Bottled Water");
        product.Price.Should().Be(20m);
        product.StockCount.Should().Be(100);
        product.IsAvailable.Should().BeTrue();
    }

    [Fact]
    public void UpdateStock_WithNegative_Throws()
    {
        var product = Product.Create("Item", 10m, ProductCategory.Misc, "Misc", 5);

        var act = () => product.UpdateStock(-1);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void ToggleAvailability_FlipsFlag()
    {
        var product = Product.Create("Item", 10m, ProductCategory.Misc, "Misc", 5);
        product.ToggleAvailability();

        product.IsAvailable.Should().BeFalse();

        product.ToggleAvailability();
        product.IsAvailable.Should().BeTrue();
    }
}

public sealed class ProductOrderEntityTests
{
    [Fact]
    public void Create_SetsPlacedStatus()
    {
        var order = ProductOrder.Create(
            Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), deliveryFee: 30m);

        order.Status.Should().Be(ProductOrderStatus.Placed);
        order.DeliveryFee.Should().Be(30m);
        order.PlacedAt.Should().BeCloseTo(DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void AddItem_RecalculatesSubTotalAndTotalAmount()
    {
        var order = ProductOrder.Create(
            Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), deliveryFee: 30m);

        order.AddItem("Bottled Water", 2, 20m);

        order.SubTotal.Should().Be(40m);
        order.TotalAmount.Should().Be(70m);
        order.Items.Should().HaveCount(1);
    }

    [Fact]
    public void Dispatch_FromPlaced_SetsDispatched()
    {
        var order = CreateDefaultOrder();
        order.Dispatch();

        order.Status.Should().Be(ProductOrderStatus.Dispatched);
    }

    [Fact]
    public void Deliver_FromDispatched_SetsDelivered()
    {
        var order = CreateDefaultOrder();
        order.Dispatch();
        order.Deliver();

        order.Status.Should().Be(ProductOrderStatus.Delivered);
        order.DeliveredAt.Should().HaveValue();
    }

    [Fact]
    public void Cancel_OnDelivered_Throws()
    {
        var order = CreateDefaultOrder();
        order.Dispatch();
        order.Deliver();

        var act = () => order.Cancel();
        act.Should().Throw<InvalidOperationException>();
    }

    private static ProductOrder CreateDefaultOrder()
        => ProductOrder.Create(
            Guid.NewGuid(), "123 Main St",
            GeoLocation.Create(11.93, 79.83), deliveryFee: 30m);
}

public sealed class UserWalletEntityTests
{
    [Fact]
    public void Create_WithBalances_SetsProperties()
    {
        var wallet = UserWallet.Create(Guid.NewGuid(), promoBalance: 500m, realBalance: 1000m);

        wallet.PromoBalance.Should().Be(500m);
        wallet.RealBalance.Should().Be(1000m);
    }

    [Fact]
    public void CreditPromo_IncreasesBalance()
    {
        var wallet = UserWallet.Create(Guid.NewGuid(), promoBalance: 100m);
        wallet.CreditPromo(50m);

        wallet.PromoBalance.Should().Be(150m);
    }

    [Fact]
    public void DebitPromo_InsufficientBalance_Throws()
    {
        var wallet = UserWallet.Create(Guid.NewGuid(), promoBalance: 50m);

        var act = () => wallet.DebitPromo(100m);
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void CreditReal_IncreasesBalance()
    {
        var wallet = UserWallet.Create(Guid.NewGuid(), realBalance: 200m);
        wallet.CreditReal(100m);

        wallet.RealBalance.Should().Be(300m);
    }

    [Fact]
    public void DebitReal_InsufficientBalance_Throws()
    {
        var wallet = UserWallet.Create(Guid.NewGuid(), realBalance: 50m);

        var act = () => wallet.DebitReal(100m);
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void DebitPromo_WithZeroAmount_Throws()
    {
        var wallet = UserWallet.Create(Guid.NewGuid(), promoBalance: 100m);

        var act = () => wallet.DebitPromo(0m);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }
}

public sealed class UserEntityTests
{
    [Fact]
    public void Create_WithShortPhone_Throws()
    {
        var act = () => User.Create("Test User", "12345", UserRole.Tourist);
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void VerifyAsLocal_OnTourist_ChangesRoleToLocal()
    {
        var user = User.Create("Test", "9000000100", UserRole.Tourist);
        user.VerifyAsLocal("aadhaar-hash-123");

        user.IsVerifiedLocal.Should().BeTrue();
        user.Role.Should().Be(UserRole.Local);
        user.AadhaarHash.Should().Be("aadhaar-hash-123");
        user.VerifiedAt.Should().HaveValue();
    }

    [Fact]
    public void ActivateProMembership_SetsIsProMemberAndExpiry()
    {
        var user = User.Create("Test", "9000000101", UserRole.Tourist);
        user.ActivateProMembership(30);

        user.IsProMember.Should().BeTrue();
        user.ProMemberUntil.Should().HaveValue();
    }

    [Fact]
    public void DeactivateProMembership_ClearsFlagAndExpiry()
    {
        var user = User.Create("Test", "9000000102", UserRole.Tourist);
        user.ActivateProMembership(30);
        user.DeactivateProMembership();

        user.IsProMember.Should().BeFalse();
        user.ProMemberUntil.Should().BeNull();
    }

    [Fact]
    public void AcceptLiabilityWaiver_SetsFlagAndTimestamp()
    {
        var user = User.Create("Test", "9000000103", UserRole.Tourist);
        user.AcceptLiabilityWaiver();

        user.HasAcceptedLiabilityWaiver.Should().BeTrue();
        user.WaiverAcceptedAt.Should().HaveValue();
    }

    [Fact]
    public void SetDrivingLicense_WithEmptyValue_Throws()
    {
        var user = User.Create("Test", "9000000104", UserRole.Tourist);

        var act = () => user.SetDrivingLicense("");
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void UpdateFcmDeviceToken_WithEmptyValue_Throws()
    {
        var user = User.Create("Test", "9000000105", UserRole.Tourist);

        var act = () => user.UpdateFcmDeviceToken("");
        act.Should().Throw<ArgumentException>();
    }
}

public sealed class AppEventLogEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var log = AppEventLog.Create(Guid.NewGuid(), "session-123", "screen_view", "{\"key\":\"value\"}");

        log.EventName.Should().Be("screen_view");
        log.SessionId.Should().Be("session-123");
        log.EventPayload.Should().Be("{\"key\":\"value\"}");
    }

    [Fact]
    public void Create_WithEmptyEventName_Throws()
    {
        var act = () => AppEventLog.Create(null, "session-123", "");
        act.Should().Throw<ArgumentException>();
    }
}

public sealed class DriverEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Ravi", "9000000200", VehicleType.Bike, "PY01AB1234");

        driver.Name.Should().Be("Ravi");
        driver.Phone.Should().Be("9000000200");
        driver.VehicleType.Should().Be(VehicleType.Bike);
        driver.VehiclePlate.Should().Be("PY01AB1234");
        driver.IsOnline.Should().BeFalse();
        driver.IsApproved.Should().BeFalse();
        driver.Rating.Should().Be(5.0);
        driver.TotalRides.Should().Be(0);
    }

    [Fact]
    public void Approve_SetsIsApproved()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Ravi", "9000000200", VehicleType.Bike);
        driver.Approve();

        driver.IsApproved.Should().BeTrue();
    }

    [Fact]
    public void GoOnline_GoOffline_TogglesIsOnline()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Ravi", "9000000200", VehicleType.Bike);
        driver.GoOnline();
        driver.IsOnline.Should().BeTrue();

        driver.GoOffline();
        driver.IsOnline.Should().BeFalse();
    }

    [Fact]
    public void UpdateLocation_SetsCurrentLocation()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Ravi", "9000000200", VehicleType.Bike);
        var loc = GeoLocation.Create(11.93, 79.83);
        driver.UpdateLocation(loc);

        driver.CurrentLocation.Should().Be(loc);
    }

    [Fact]
    public void RecordRideCompleted_IncrementsTotalRides()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Ravi", "9000000200", VehicleType.Bike);
        driver.RecordRideCompleted();
        driver.RecordRideCompleted();

        driver.TotalRides.Should().Be(2);
    }

    [Fact]
    public void UploadKyc_SetsUrlsAndFlag()
    {
        var driver = Driver.Create(Guid.NewGuid(), "Ravi", "9000000200", VehicleType.Bike);
        driver.UploadKyc("https://aadhaar.url", "https://dl.url", "https://rc.url", "ravi@upi");

        driver.AadhaarUrl.Should().Be("https://aadhaar.url");
        driver.DrivingLicenseUrl.Should().Be("https://dl.url");
        driver.RcUrl.Should().Be("https://rc.url");
        driver.UpiId.Should().Be("ravi@upi");
        driver.IsKycUploaded.Should().BeTrue();
    }
}

public sealed class HomestayEntityTests
{
    [Fact]
    public void Create_SetsFieldsAndIsVerifiedFalse()
    {
        var homestay = Homestay.Create(
            Guid.NewGuid(), "Beach House", "Nice place", "White Town",
            11.93, 79.83, nightlyRate: 1500m, maxGuests: 4, hasWifi: true);

        homestay.Name.Should().Be("Beach House");
        homestay.NightlyRate.Should().Be(1500m);
        homestay.MaxGuests.Should().Be(4);
        homestay.HasWifi.Should().BeTrue();
        homestay.IsVerified.Should().BeFalse();
    }

    [Fact]
    public void UpdateDetails_UpdatesAllFields()
    {
        var homestay = Homestay.Create(
            Guid.NewGuid(), "Beach House", "Nice place", "White Town",
            11.93, 79.83, nightlyRate: 1500m, maxGuests: 4);
        homestay.UpdateDetails("New Name", "New Desc", "Rock Beach",
            11.94, 79.84, nightlyRate: 2000m, maxGuests: 6, hasWifi: false);

        homestay.Name.Should().Be("New Name");
        homestay.NightlyRate.Should().Be(2000m);
        homestay.MaxGuests.Should().Be(6);
        homestay.HasWifi.Should().BeFalse();
    }

    [Fact]
    public void Verify_SetsIsVerifiedTrue()
    {
        var homestay = Homestay.Create(
            Guid.NewGuid(), "Beach House", "Nice place", "White Town",
            11.93, 79.83, nightlyRate: 1500m, maxGuests: 4);
        homestay.Verify();

        homestay.IsVerified.Should().BeTrue();
    }

    [Fact]
    public void Create_WithZeroMaxGuests_Throws()
    {
        var act = () => Homestay.Create(
            Guid.NewGuid(), "Beach House", "Nice place", "White Town",
            11.93, 79.83, nightlyRate: 1500m, maxGuests: 0);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }
}

public sealed class MenuItemEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var item = MenuItem.Create(
            Guid.NewGuid(), "Margherita Pizza", 250m, "Pizzas",
            description: "Classic cheese pizza", isLateNight: true);

        item.Name.Should().Be("Margherita Pizza");
        item.Price.Should().Be(250m);
        item.Category.Should().Be("Pizzas");
        item.IsAvailable.Should().BeTrue();
        item.IsLateNight.Should().BeTrue();
    }

    [Fact]
    public void UpdatePrice_WithZero_Throws()
    {
        var item = MenuItem.Create(Guid.NewGuid(), "Pizza", 250m, "Pizzas");

        var act = () => item.UpdatePrice(0m);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void UpdateDetails_UpdatesNameDescriptionCategory()
    {
        var item = MenuItem.Create(Guid.NewGuid(), "Pizza", 250m, "Pizzas");
        item.UpdateDetails("Calzone", "Folded pizza", "Calzones");

        item.Name.Should().Be("Calzone");
        item.Description.Should().Be("Folded pizza");
        item.Category.Should().Be("Calzones");
    }

    [Fact]
    public void ToggleAvailability_FlipsFlag()
    {
        var item = MenuItem.Create(Guid.NewGuid(), "Pizza", 250m, "Pizzas");
        item.ToggleAvailability();

        item.IsAvailable.Should().BeFalse();

        item.ToggleAvailability();
        item.IsAvailable.Should().BeTrue();
    }
}

public sealed class RoomAvailabilityEntityTests
{
    [Fact]
    public void Create_SetsIsBookedFalse()
    {
        var room = RoomAvailability.Create(Guid.NewGuid(), new DateOnly(2026, 1, 15));

        room.IsBooked.Should().BeFalse();
        room.LockedByBookingId.Should().BeNull();
    }

    [Fact]
    public void Lock_SetsIsBookedAndBookingId()
    {
        var room = RoomAvailability.Create(Guid.NewGuid(), new DateOnly(2026, 1, 15));
        var bookingId = Guid.NewGuid();
        room.Lock(bookingId);

        room.IsBooked.Should().BeTrue();
        room.LockedByBookingId.Should().Be(bookingId);
    }

    [Fact]
    public void Lock_OnAlreadyBooked_Throws()
    {
        var room = RoomAvailability.Create(Guid.NewGuid(), new DateOnly(2026, 1, 15));
        room.Lock(Guid.NewGuid());

        var act = () => room.Lock(Guid.NewGuid());
        act.Should().Throw<InvalidOperationException>();
    }
}

public sealed class SubscriptionPlanEntityTests
{
    [Fact]
    public void Create_SetsFieldsAndPerks()
    {
        var perks = new[] { PerkType.ZeroConvenienceFees, PerkType.SkipTheLine };
        var plan = SubscriptionPlan.Create("Pro", SubscriptionPlanType.Pro, 299m, 30, "Pro plan", perks);

        plan.Name.Should().Be("Pro");
        plan.Price.Should().Be(299m);
        plan.DurationDays.Should().Be(30);
        plan.IsActive.Should().BeTrue();
        plan.Perks.Should().HaveCount(2);
    }

    [Fact]
    public void AddPerk_AddsUniquePerkOnly()
    {
        var plan = SubscriptionPlan.Create("Pro", SubscriptionPlanType.Pro, 299m, 30);
        plan.AddPerk(PerkType.ZeroConvenienceFees);
        plan.AddPerk(PerkType.ZeroConvenienceFees);

        plan.Perks.Should().HaveCount(1);
    }

    [Fact]
    public void RemovePerk_RemovesPerk()
    {
        var plan = SubscriptionPlan.Create("Pro", SubscriptionPlanType.Pro, 299m, 30,
            perks: new[] { PerkType.ZeroConvenienceFees });
        plan.RemovePerk(PerkType.ZeroConvenienceFees);

        plan.Perks.Should().BeEmpty();
    }

    [Fact]
    public void SetActive_TogglesIsActive()
    {
        var plan = SubscriptionPlan.Create("Pro", SubscriptionPlanType.Pro, 299m, 30);
        plan.SetActive(false);

        plan.IsActive.Should().BeFalse();

        plan.SetActive(true);
        plan.IsActive.Should().BeTrue();
    }
}

public sealed class UserSubscriptionEntityTests
{
    [Fact]
    public void Create_SetsIsActiveAndExpiresAt()
    {
        var startsAt = DateTimeOffset.UtcNow;
        var sub = UserSubscription.Create(Guid.NewGuid(), Guid.NewGuid(), startsAt, 30);

        sub.IsActive.Should().BeTrue();
        sub.ExpiresAt.Should().Be(startsAt.AddDays(30));
    }

    [Fact]
    public void Cancel_SetsIsActiveFalse()
    {
        var sub = UserSubscription.Create(Guid.NewGuid(), Guid.NewGuid(), DateTimeOffset.UtcNow, 30);
        sub.Cancel();

        sub.IsActive.Should().BeFalse();
    }

    [Fact]
    public void IsValidAt_WithinRange_ReturnsTrue()
    {
        var startsAt = DateTimeOffset.UtcNow;
        var sub = UserSubscription.Create(Guid.NewGuid(), Guid.NewGuid(), startsAt, 30);

        sub.IsValidAt(startsAt.AddDays(10)).Should().BeTrue();
        sub.IsValidAt(startsAt.AddDays(31)).Should().BeFalse();
    }
}

public sealed class TransitHubEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var hub = TransitHub.Create("Pondy Bus Stand", TransitHubKind.BusStation,
            GeoLocation.Create(11.93, 79.83), "Main Road");

        hub.Name.Should().Be("Pondy Bus Stand");
        hub.Kind.Should().Be(TransitHubKind.BusStation);
        hub.IsActive.Should().BeTrue();
    }

    [Fact]
    public void UpdateDetails_UpdatesNameAndAddress()
    {
        var hub = TransitHub.Create("Old Name", TransitHubKind.BusStation,
            GeoLocation.Create(11.93, 79.83), "Old Address");
        hub.UpdateDetails("New Name", "New Address");

        hub.Name.Should().Be("New Name");
        hub.Address.Should().Be("New Address");
    }

    [Fact]
    public void ToggleActive_SetsIsActive()
    {
        var hub = TransitHub.Create("Hub", TransitHubKind.Airport,
            GeoLocation.Create(11.93, 79.83));
        hub.ToggleActive(false);

        hub.IsActive.Should().BeFalse();
    }
}

public sealed class WaitlistEntryEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var entry = WaitlistEntry.Create("9000000300", "QR-Location-1");

        entry.PhoneNumber.Should().Be("9000000300");
        entry.SourceQrCodeLocation.Should().Be("QR-Location-1");
        entry.IsConverted.Should().BeFalse();
    }

    [Fact]
    public void Create_WithShortPhone_Throws()
    {
        var act = () => WaitlistEntry.Create("12345");
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void MarkConverted_SetsIsConvertedAndConvertedAt()
    {
        var entry = WaitlistEntry.Create("9000000300");
        entry.MarkConverted();

        entry.IsConverted.Should().BeTrue();
        entry.ConvertedAt.Should().HaveValue();
    }
}

public sealed class VendorPromotionEntityTests
{
    [Fact]
    public void Create_SetsFieldsAndIsActiveTrue()
    {
        var now = DateTimeOffset.UtcNow;
        var promo = VendorPromotion.Create(
            Guid.NewGuid(), PromoType.FlashSale, "Summer Sale", 100m, now, now.AddDays(7),
            description: "Big sale", discountPercentage: 20m);

        promo.Title.Should().Be("Summer Sale");
        promo.Cost.Should().Be(100m);
        promo.DiscountPercentage.Should().Be(20m);
        promo.IsActive.Should().BeTrue();
    }

    [Fact]
    public void Create_WithExpiresAtBeforeStartsAt_Throws()
    {
        var now = DateTimeOffset.UtcNow;
        var act = () => VendorPromotion.Create(
            Guid.NewGuid(), PromoType.FlashSale, "Bad Promo", 100m, now, now.AddDays(-1));

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Create_WithDiscountOver100_Throws()
    {
        var now = DateTimeOffset.UtcNow;
        var act = () => VendorPromotion.Create(
            Guid.NewGuid(), PromoType.FlashSale, "Bad Discount", 100m, now, now.AddDays(7),
            discountPercentage: 150m);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void Deactivate_SetsIsActiveFalse()
    {
        var now = DateTimeOffset.UtcNow;
        var promo = VendorPromotion.Create(Guid.NewGuid(), PromoType.TopListing, "Promo", 50m, now, now.AddDays(7));
        promo.Deactivate();

        promo.IsActive.Should().BeFalse();
    }

    [Fact]
    public void SetDiscount_WithValidPercentage_UpdatesDiscount()
    {
        var now = DateTimeOffset.UtcNow;
        var promo = VendorPromotion.Create(Guid.NewGuid(), PromoType.FlashSale, "Promo", 50m, now, now.AddDays(7));
        promo.SetDiscount(30m);

        promo.DiscountPercentage.Should().Be(30m);
    }

    [Fact]
    public void IsValidAt_WithinRange_ReturnsTrue()
    {
        var now = DateTimeOffset.UtcNow;
        var promo = VendorPromotion.Create(Guid.NewGuid(), PromoType.FlashSale, "Promo", 50m, now, now.AddDays(7));

        promo.IsValidAt(now.AddDays(3)).Should().BeTrue();
        promo.IsValidAt(now.AddDays(8)).Should().BeFalse();
    }

    [Fact]
    public void IsValidAt_AfterDeactivate_ReturnsFalse()
    {
        var now = DateTimeOffset.UtcNow;
        var promo = VendorPromotion.Create(Guid.NewGuid(), PromoType.FlashSale, "Promo", 50m, now, now.AddDays(7));
        promo.Deactivate();

        promo.IsValidAt(now.AddDays(3)).Should().BeFalse();
    }
}

public sealed class SupportTicketEntityTests
{
    [Fact]
    public void Create_SetsDefaults()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());

        ticket.Status.Should().Be(SupportTicketStatus.Open);
        ticket.Priority.Should().Be(TicketPriority.Normal);
        ticket.Source.Should().Be(TicketSource.InApp);
    }

    [Fact]
    public void Create_WithSosSource_SetsSosSource()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid(), TicketPriority.Critical, TicketSource.SOS,
            latitude: 11.93, longitude: 79.83, issueCategory: "Breakdown");

        ticket.Source.Should().Be(TicketSource.SOS);
        ticket.Priority.Should().Be(TicketPriority.Critical);
        ticket.IssueCategory.Should().Be("Breakdown");
        ticket.Latitude.Should().Be(11.93);
    }

    [Fact]
    public void Escalate_SetsCriticalAndEscalated()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());
        ticket.Escalate();

        ticket.Priority.Should().Be(TicketPriority.Critical);
        ticket.Status.Should().Be(SupportTicketStatus.Escalated);
    }

    [Fact]
    public void MarkInProgress_FromOpen_SetsInProgress()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());
        ticket.MarkInProgress();

        ticket.Status.Should().Be(SupportTicketStatus.InProgress);
    }

    [Fact]
    public void MarkInProgress_FromEscalated_DoesNotChange()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());
        ticket.Escalate();
        ticket.MarkInProgress();

        ticket.Status.Should().Be(SupportTicketStatus.Escalated);
    }

    [Fact]
    public void Resolve_SetsResolvedAndResolvedAt()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());
        ticket.Resolve();

        ticket.Status.Should().Be(SupportTicketStatus.Resolved);
        ticket.ResolvedAt.Should().HaveValue();
    }

    [Fact]
    public void Acknowledge_SetsAcknowledgedAt()
    {
        var ticket = SupportTicket.Create(Guid.NewGuid());
        ticket.Acknowledge();

        ticket.AcknowledgedAt.Should().HaveValue();
    }
}

public sealed class TicketMessageEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var msg = TicketMessage.Create(Guid.NewGuid(), MessageSenderRole.User, "Help me!");

        msg.MessageText.Should().Be("Help me!");
        msg.SenderRole.Should().Be(MessageSenderRole.User);
    }

    [Fact]
    public void Create_WithEmptyText_Throws()
    {
        var act = () => TicketMessage.Create(Guid.NewGuid(), MessageSenderRole.AI, "");
        act.Should().Throw<ArgumentException>();
    }
}

public sealed class DriverLedgerEntryEntityTests
{
    [Fact]
    public void Create_SetsFields()
    {
        var entry = DriverLedgerEntry.Create(Guid.NewGuid(), 250m, LedgerTransactionType.Earning, "RIDE-001");

        entry.Amount.Should().Be(250m);
        entry.TransactionType.Should().Be(LedgerTransactionType.Earning);
        entry.Reference.Should().Be("RIDE-001");
    }

    [Fact]
    public void Create_WithNegativeAmount_ForWithdrawal_Succeeds()
    {
        var entry = DriverLedgerEntry.Create(Guid.NewGuid(), -100m, LedgerTransactionType.Withdrawal, "PAYOUT-001");

        entry.Amount.Should().Be(-100m);
        entry.TransactionType.Should().Be(LedgerTransactionType.Withdrawal);
    }

    [Fact]
    public void Create_WithBonusType_SetsBonus()
    {
        var entry = DriverLedgerEntry.Create(Guid.NewGuid(), 50m, LedgerTransactionType.Bonus, "LATE-NIGHT");

        entry.TransactionType.Should().Be(LedgerTransactionType.Bonus);
    }
}

public sealed class DispatchTaskEntityTests
{
    [Fact]
    public void Create_SetsFieldsAndAvailableStatus()
    {
        var task = DispatchTask.Create(
            DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83),
            GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff",
            driverEarnings: 80m);

        task.TaskType.Should().Be(DispatchTaskType.Ride);
        task.Status.Should().Be(DispatchTaskStatus.Available);
        task.DriverEarnings.Should().Be(80m);
        task.DriverId.Should().BeNull();
    }

    [Fact]
    public void Assign_SetsDriverIdAndAssignedStatus()
    {
        var task = DispatchTask.Create(DispatchTaskType.FoodDelivery,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);
        var driverId = Guid.NewGuid();
        task.Assign(driverId);

        task.DriverId.Should().Be(driverId);
        task.Status.Should().Be(DispatchTaskStatus.Assigned);
    }

    [Fact]
    public void Assign_OnAlreadyAssigned_Throws()
    {
        var task = DispatchTask.Create(DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);
        task.Assign(Guid.NewGuid());

        var act = () => task.Assign(Guid.NewGuid());
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Start_FromAssigned_SetsInProgress()
    {
        var task = DispatchTask.Create(DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);
        task.Assign(Guid.NewGuid());
        task.Start();

        task.Status.Should().Be(DispatchTaskStatus.InProgress);
    }

    [Fact]
    public void Start_FromAvailable_Throws()
    {
        var task = DispatchTask.Create(DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);

        var act = () => task.Start();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Complete_FromInProgress_SetsCompleted()
    {
        var task = DispatchTask.Create(DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);
        task.Assign(Guid.NewGuid());
        task.Start();
        task.Complete();

        task.Status.Should().Be(DispatchTaskStatus.Completed);
    }

    [Fact]
    public void Cancel_FromAvailable_SetsCancelled()
    {
        var task = DispatchTask.Create(DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);
        task.Cancel();

        task.Status.Should().Be(DispatchTaskStatus.Cancelled);
    }

    [Fact]
    public void Cancel_OnCompleted_IsNoOp()
    {
        var task = DispatchTask.Create(DispatchTaskType.Ride,
            GeoLocation.Create(11.93, 79.83), GeoLocation.Create(11.94, 79.84),
            "Pickup", "Dropoff", 50m);
        task.Assign(Guid.NewGuid());
        task.Start();
        task.Complete();
        task.Cancel();

        task.Status.Should().Be(DispatchTaskStatus.Completed);
    }
}
