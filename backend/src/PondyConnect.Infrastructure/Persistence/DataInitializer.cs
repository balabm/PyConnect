namespace PondyConnect.Infrastructure.Persistence;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Applies pending migrations and seeds a small demo dataset so the
/// Nightlife &amp; Dining module (Phase 2) has venues to surface immediately.
///
/// Demo data (venues, drivers, vendors, etc.) is only seeded when
/// <c>SeedDemoData</c> is <c>true</c> in configuration. In production,
/// only the admin user and Fuoco Pizzeria (if explicitly enabled) are seeded.
/// All other data must come from real vendor/driver onboarding.
/// </summary>
public sealed class DataInitializer
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly bool _seedDemoData;

    public DataInitializer(ApplicationDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
        _seedDemoData = configuration.GetValue<bool>("SeedDemoData", defaultValue: false);
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_context.Database.ProviderName == "Npgsql.EntityFrameworkCore.PostgreSQL")
            await _context.Database.MigrateAsync(cancellationToken);
        else
            await _context.Database.EnsureCreatedAsync(cancellationToken);

        // Always seed the admin user so the system is manageable on first boot.
        await SeedAdminUserAsync(cancellationToken);

        // Demo data (venues, vendors, drivers, menus, etc.) is only seeded
        // in development/staging. In production, all data comes from real
        // vendor/driver onboarding via the Partner and Driver apps.
        if (!_seedDemoData)
            return;

        // The Fuoco venue is always seeded below, so an "any venue exists" check
        // can never guard the demo dataset. Use the flagship nightlife venue as the
        // idempotency marker instead so consumer amenities seed exactly once.
        if (!await _context.Venues.AnyAsync(v => v.Name == "Drunken Daddy", cancellationToken))
        {
            await SeedDemoDatasetAsync(cancellationToken);
        }

        await SeedFuocoPizzeriaAsync(cancellationToken);
        await SeedMenuItemsAsync(cancellationToken);
        await SeedRestaurantsAsync(cancellationToken);
        // Quick Essentials module disabled — product seeding removed
        // await SeedProductsAsync(cancellationToken);
        await SeedDriversAsync(cancellationToken);
        await SeedFlashPromosAsync(cancellationToken);
        await SeedTestPassesAsync(cancellationToken);
        await SeedVendorCreditAsync(cancellationToken);
        await SeedDriverKycAndLedgerAsync(cancellationToken);
        await SeedHomestaysAsync(cancellationToken);
        await SeedSupportTicketsAsync(cancellationToken);
        await SeedPartySupplierAsync(cancellationToken);
    }

    private async Task SeedAdminUserAsync(CancellationToken cancellationToken)
    {
        if (await _context.Users.AnyAsync(u => u.Role == UserRole.Admin, cancellationToken))
            return;

        // Admin phone comes from configuration so the auto-seeded admin
        // is not a well-known public number. If no phone is configured,
        // skip auto-seeding — the operator must create the first admin
        // through a secure bootstrap process or migration.
        var adminPhone = _configuration.GetValue<string>("Admin:BootstrapPhone");
        if (string.IsNullOrWhiteSpace(adminPhone))
            return;

        var admin = User.Create("Admin", adminPhone, UserRole.Admin);
        admin.AcceptLiabilityWaiver();
        _context.Users.Add(admin);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedDemoDatasetAsync(CancellationToken cancellationToken)
    {
        var venues = new[]
        {
            Venue.Create(
                "Kasha Ki Aasha",
                VenueCategory.Pub,
                GeoLocation.Create(11.9362, 79.8346),
                maxCapacity: 120,
                description: "Iconic White Town pub with live gigs.",
                address: "10, Rue Romain Rolland, White Town",
                imageUrl: "https://images.unsplash.com/photo-1572116469636-31def3b0?w=400",
                rating: 4.3,
                reviewCount: 127),
            Venue.Create(
                "The Turtles Cafe",
                VenueCategory.Cafe,
                GeoLocation.Create(11.9370, 79.8338),
                maxCapacity: 60,
                description: "Bicycle-themed cafe famous for full English breakfast.",
                address: "31 Suffren Street, White Town",
                imageUrl: "https://images.unsplash.com/photo-1554118811-1b4dc0715938?w=400",
                rating: 4.1,
                reviewCount: 89),
            Venue.Create(
                "La Maison Rose",
                VenueCategory.Restaurant,
                GeoLocation.Create(11.9357, 79.8331),
                maxCapacity: 48,
                description: "French bistro in a restored colonial bungalow.",
                address: "11 Rue Cluny, White Town",
                imageUrl: "https://images.unsplash.com/photo-1517248135467-3c7ed8826398?w=400",
                rating: 4.6,
                reviewCount: 203),
            Venue.Create(
                "Promotion Beach Riders",
                VenueCategory.Experience,
                GeoLocation.Create(12.0159, 79.8537),
                maxCapacity: 200,
                description: "Rent a scooter for a lazy lap around the boulevard.",
                address: "Beach Road, Promenade"),
            Venue.Create(
                "Matrimandir Viewing",
                VenueCategory.Experience,
                GeoLocation.Create(12.0104, 79.8112),
                maxCapacity: 50,
                description: "Inner chamber viewing slot at the Auroville Matrimandir.",
                address: "Auroville, Matrimandir"),
            Venue.Create(
                "French Quarter Heritage Walk",
                VenueCategory.Experience,
                GeoLocation.Create(11.9350, 79.8330),
                maxCapacity: 25,
                description: "Guided walking tour through colonial White Town streets.",
                address: "Rue Dumas, White Town"),
            Venue.Create(
                "Le Club",
                VenueCategory.Club,
                GeoLocation.Create(11.9349, 79.8362),
                maxCapacity: 150,
                description: "Pondicherry's hottest nightclub with DJ nights and dance floor.",
                address: "56, Beach Road, White Town",
                imageUrl: "https://images.unsplash.com/photo-1571227208482-1f4cbfb5d359?w=400",
                rating: 4.4,
                reviewCount: 312),
            Venue.Create(
                "Ashoka Beach Bar",
                VenueCategory.Bar,
                GeoLocation.Create(11.9341, 79.8365),
                maxCapacity: 90,
                description: "Beachfront bar with sunset cocktails and live acoustic sets.",
                address: "27, Beach Road, White Town",
                imageUrl: "https://images.unsplash.com/photo-1543007630-9710e4a00a20?w=400",
                rating: 4.2,
                reviewCount: 156),
            Venue.Create(
                "Baker Street Bistro",
                VenueCategory.Bakery,
                GeoLocation.Create(11.9368, 79.8340),
                maxCapacity: 40,
                description: "Artisanal bakery serving fresh croissants and quiches.",
                address: "14, Rue Bourbon, White Town",
                imageUrl: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400",
                rating: 4.3,
                reviewCount: 78),
            Venue.Create(
                "Café des Arts",
                VenueCategory.Cafe,
                GeoLocation.Create(11.9358, 79.8335),
                maxCapacity: 55,
                description: "AC cafe with gallery space, perfect for afternoon heat escape.",
                address: "16, Rue Suffren, White Town",
                imageUrl: "https://images.unsplash.com/photo-1453614512568-c4024d13c247?w=400",
                rating: 4.4,
                reviewCount: 145),
            Venue.Create(
                "Satsanga Restaurant",
                VenueCategory.Restaurant,
                GeoLocation.Create(11.9365, 79.8355),
                maxCapacity: 70,
                description: "Multi-cuisine garden restaurant with outdoor seating.",
                address: "45, Rue Romain Rolland, White Town",
                imageUrl: "https://images.unsplash.com/photo-1517248135467-4c7ed8826398?w=400",
                rating: 4.2,
                reviewCount: 110),
            Venue.Create(
                "Zero House Pub",
                VenueCategory.Pub,
                GeoLocation.Create(11.9352, 79.8348),
                maxCapacity: 100,
                description: "Rooftop pub with craft beer and panoramic White Town views.",
                address: "8, Rue de la Marine, White Town",
                imageUrl: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=400",
                rating: 4.0,
                reviewCount: 98),
            Venue.Create(
                "Pondy Pizzeria",
                VenueCategory.Pizzeria,
                GeoLocation.Create(11.9375, 79.8342),
                maxCapacity: 65,
                description: "Family-friendly pizzeria with wood-fired ovens.",
                address: "22, Rue Saint Gilles, White Town",
                imageUrl: "https://images.unsplash.com/photo-1513104890138-746a492e0b31?w=400",
                rating: 4.0,
                reviewCount: 95),
            // ── Flagship nightlife venues (E2E testing) ──
            Venue.Create(
                "Drunken Daddy",
                VenueCategory.Pub,
                GeoLocation.Create(11.9355, 79.8340),
                maxCapacity: 50,
                description: "Flagship White Town pub with craft cocktails and late-night DJ sets.",
                address: "5, Rue Romain Rolland, White Town",
                imageUrl: "https://images.unsplash.com/photo-1572116469636-31def3b0?w=400",
                rating: 4.5,
                reviewCount: 240),
            Venue.Create(
                "The Fixx",
                VenueCategory.Pub,
                GeoLocation.Create(11.9360, 79.8345),
                maxCapacity: 50,
                description: "Industrial-chic bar with live music, pool tables, and late-night kitchen.",
                address: "12, Rue Suffren, White Town",
                imageUrl: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=400",
                rating: 4.3,
                reviewCount: 185),
            Venue.Create(
                "Royal Brothers White Town",
                VenueCategory.Experience,
                GeoLocation.Create(11.9365, 79.8335),
                maxCapacity: 30,
                description: "Premium scooter and motorcycle rentals for White Town exploration.",
                address: "18, Rue de la Marine, White Town"),
            Venue.Create(
                "Promenade SafeDrop",
                VenueCategory.Experience,
                GeoLocation.Create(11.9345, 79.8360),
                maxCapacity: 100,
                description: "Secure 24/7 luggage cloak room on the Rock Beach promenade.",
                address: "Beach Road, Promenade, White Town")
        };

        // Activate Priority Ping for flagship nightlife venues
        var drunkenDaddy = venues.First(v => v.Name == "Drunken Daddy");
        drunkenDaddy.ActivatePriorityPing();
        var theFixx = venues.First(v => v.Name == "The Fixx");
        theFixx.ActivatePriorityPing();

        var hubs = new[]
        {
            TransitHub.Create(
                "Pondicherry Bus Stand",
                TransitHubKind.BusStation,
                GeoLocation.Create(11.9390, 79.8350),
                "Marai Malai Adigal Salai, Puducherry"),
            TransitHub.Create(
                "Pondicherry Airport (PNY)",
                TransitHubKind.Airport,
                GeoLocation.Create(11.9685, 79.8138),
                "Airport Road, Lawspet, Puducherry"),
            TransitHub.Create(
                "Puducherry Railway Station",
                TransitHubKind.RailwayStation,
                GeoLocation.Create(11.9402, 79.8355),
                "South Boulevard, Puducherry")
        };

        var vendors = new[]
        {
            Vendor.Create("Café Veloute Cloak", VendorCategory.LuggageCloak, contactPhone: "9000011111"),
            Vendor.Create("Le Clocher Bag Storage", VendorCategory.LuggageCloak, contactPhone: "9000022222"),
            Vendor.Create("White Town Luggage Lounge", VendorCategory.LuggageCloak, contactPhone: "9000044444"),
            Vendor.Create("Promenade Cloak Room", VendorCategory.LuggageCloak, contactPhone: "9000055555"),
            Vendor.Create("Beach Road Bag Drop", VendorCategory.LuggageCloak, contactPhone: "9000066666"),
            Vendor.Create("Promotion Scooter Rentals", VendorCategory.ScooterRental, contactPhone: "9000033333"),
            // ── Flagship nightlife vendors (E2E testing) ──
            Vendor.Create("Drunken Daddy", VendorCategory.PubClub, contactPhone: "9000000010", cuisineType: "Pub & Cocktails", rating: 4.5, description: "Flagship White Town pub with craft cocktails and late-night DJ sets."),
            Vendor.Create("The Fixx", VendorCategory.PubClub, contactPhone: "9000000011", cuisineType: "Pub & Grill", rating: 4.3, description: "Industrial-chic bar with live music, pool tables, and late-night kitchen."),
            Vendor.Create("Royal Brothers White Town", VendorCategory.ScooterRental, contactPhone: "9000000012", description: "Premium scooter and motorcycle rentals for White Town exploration."),
            Vendor.Create("Promenade SafeDrop", VendorCategory.LuggageCloak, contactPhone: "9000000013", description: "Secure 24/7 luggage cloak room on the Rock Beach promenade.")
        };
        foreach (var vendor in vendors)
            vendor.Approve();

        // Save vendors first so we can link venues to their IDs.
        _context.Vendors.AddRange(vendors);
        await _context.SaveChangesAsync(cancellationToken);

        // Link nightlife venues to their corresponding vendors by name.
        // Without this, the venue VendorId stays NULL and the partner app
        // gets a 404 when querying GET /api/vendor/venues.
        var vendorByName = vendors.ToDictionary(v => v.Name);
        foreach (var venue in venues)
        {
            if (vendorByName.TryGetValue(venue.Name, out var matchedVendor))
            {
                venue.SetVendorId(matchedVendor.Id);
            }
        }

        // Create vendor owner users for the flagship nightlife vendors so
        // they can log in to the Partner app via OTP. Without a User row,
        // the OTP verify handler throws "No vendor profile is linked to
        // this phone number" because the user doesn't exist yet.
        var nightlifeOwnerPhones = new[]
        {
            ("Drunken Daddy Owner", "9000000010"),
            ("The Fixx Owner", "9000000011"),
            ("Royal Brothers Owner", "9000000012"),
            ("Promenade SafeDrop Owner", "9000000013"),
        };
        foreach (var (ownerName, phone) in nightlifeOwnerPhones)
        {
            if (!await _context.Users.AnyAsync(u => u.Phone == phone, cancellationToken))
            {
                _context.Users.Add(User.Create(ownerName, phone, UserRole.Vendor));
            }
        }
        await _context.SaveChangesAsync(cancellationToken);

        _context.Venues.AddRange(venues);
        _context.TransitHubs.AddRange(hubs);

        await _context.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Seeds "Fuoco Pizzeria" (vendor #1) with a linked owner account (phone
    /// 9000000001) and a White Town venue so the B2B portal has a demo login.
    /// </summary>
    private async Task SeedFuocoPizzeriaAsync(CancellationToken cancellationToken)
    {
        var fuocoVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");

        var owner = await _context.Users.FirstOrDefaultAsync(u => u.Phone == "9000000001", cancellationToken);
        if (owner is null)
        {
            _context.Users.Add(User.Create("Ravi Fuoco", "9000000001", UserRole.Vendor));
            await _context.SaveChangesAsync(cancellationToken);
        }

        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == fuocoVendorId, cancellationToken);
        if (vendor is null)
        {
            var created = Vendor.CreateForSeed(
                fuocoVendorId,
                "Fuoco Pizzeria",
                VendorCategory.Restaurant,
                contactPhone: "9000000001",
                merchantReference: "FUOCO-001",
                cuisineType: "Italian",
                rating: 4.5,
                imageUrl: "https://images.unsplash.com/photo-1513104890138-746a492e0b31?w=800",
                description: "Wood-fired artisanal pizzeria in the heart of White Town.",
                deliveryFee: 40m,
                prepTimeMinutes: 25);
            created.Approve();
            _context.Vendors.Add(created);
            await _context.SaveChangesAsync(cancellationToken);
        }

        if (!await _context.Venues.AnyAsync(v => v.VendorId == fuocoVendorId, cancellationToken))
        {
            _context.Venues.Add(CreateFuocoVenue(fuocoVendorId));
            await _context.SaveChangesAsync(cancellationToken);
        }
    }

    private static Venue CreateFuocoVenue(Guid vendorId)
    {
        var venue = Venue.Create(
            "Fuoco Pizzeria",
            VenueCategory.Pizzeria,
            GeoLocation.Create(11.9348, 79.8346),
            maxCapacity: 80,
            vendorId: vendorId,
            description: "Wood-fired artisanal pizzeria in the heart of White Town.",
            address: "Rue de la Marine, White Town, Puducherry",
            imageUrl: "https://images.unsplash.com/photo-1513104890138-746a492e0b31?w=800",
            rating: 4.5,
            reviewCount: 320);

        venue.AddAvailability(DayOfWeek.Monday, new TimeOnly(12, 0), new TimeOnly(23, 0));
        venue.AddAvailability(DayOfWeek.Tuesday, new TimeOnly(12, 0), new TimeOnly(23, 0));
        venue.AddAvailability(DayOfWeek.Wednesday, new TimeOnly(12, 0), new TimeOnly(23, 0));
        venue.AddAvailability(DayOfWeek.Thursday, new TimeOnly(12, 0), new TimeOnly(23, 0));
        venue.AddAvailability(DayOfWeek.Friday, new TimeOnly(12, 0), new TimeOnly(23, 30));
        venue.AddAvailability(DayOfWeek.Saturday, new TimeOnly(12, 0), new TimeOnly(23, 30));
        venue.AddAvailability(DayOfWeek.Sunday, new TimeOnly(12, 0), new TimeOnly(23, 0));
        return venue;
    }

    private async Task SeedMenuItemsAsync(CancellationToken cancellationToken)
    {
        var fuocoVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        if (await _context.MenuItems.AnyAsync(m => m.VendorId == fuocoVendorId && m.Name == "Woodfired Margherita", cancellationToken))
            return;

        // Clear old menu items if they exist with outdated names
        var existingItems = await _context.MenuItems
            .Where(m => m.VendorId == fuocoVendorId)
            .ToListAsync(cancellationToken);
        if (existingItems.Count > 0)
        {
            _context.MenuItems.RemoveRange(existingItems);
            await _context.SaveChangesAsync(cancellationToken);
        }

        var menuItems = new[]
        {
            MenuItem.Create(fuocoVendorId, "Woodfired Margherita", 450m, "Pizza", description: "San Marzano tomato, fresh buffalo mozzarella, basil, EVOO.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1574071318508-1cdbab80b25f?w=400"),
            MenuItem.Create(fuocoVendorId, "Truffle Fries", 250m, "Sides", description: "Hand-cut fries tossed in truffle oil and parmesan.", imageUrl: "https://images.unsplash.com/photo-1639024471283-03518883512d?w=400"),
            MenuItem.Create(fuocoVendorId, "Pepperoni Pizza", 550m, "Pizza", description: "Double pepperoni, mozzarella, San Marzano sauce.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1593564705826-36b9403c0c66?w=400"),
            MenuItem.Create(fuocoVendorId, "Garlic Bread", 150m, "Sides", description: "Toasted ciabatta with herb butter and parmesan.", imageUrl: "https://images.unsplash.com/photo-1573140246462-332f2d2b4c91?w=400"),
            MenuItem.Create(fuocoVendorId, "Tiramisu", 220m, "Dessert", description: "Classic Italian coffee-soaked layers with mascarpone cream.", imageUrl: "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=400"),
            MenuItem.Create(fuocoVendorId, "Chicken Wings (6 pc)", 280m, "Sides", description: "Buffalo-style hot wings with blue cheese dip.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400"),
            MenuItem.Create(fuocoVendorId, "Chicken Shawarma", 180m, "Shawarma", description: "Lebanese-style rolled shawarma with garlic sauce.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1639024471283-03518883512d?w=400")
        };

        _context.MenuItems.AddRange(menuItems);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedRestaurantsAsync(CancellationToken cancellationToken)
    {
        // Fuoco Pizzeria (vendor #1) is already seeded — seed 11 additional restaurants
        var seedVendors = new[]
        {
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000002"), Name: "Satsanga Garden Kitchen", Category: VendorCategory.Restaurant, Cuisine: "Indian", Rating: 4.2, DeliveryFee: 30m, PrepTime: 20, Desc: "Multi-cuisine garden restaurant with outdoor seating."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000003"), Name: "La Maison Rose", Category: VendorCategory.Restaurant, Cuisine: "French", Rating: 4.6, DeliveryFee: 50m, PrepTime: 30, Desc: "French bistro in a restored colonial bungalow."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000004"), Name: "Baker Street Bistro", Category: VendorCategory.Cafe, Cuisine: "Bakery", Rating: 4.3, DeliveryFee: 25m, PrepTime: 15, Desc: "Artisanal bakery serving fresh croissants and quiches."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000005"), Name: "Café des Arts", Category: VendorCategory.Cafe, Cuisine: "Cafe", Rating: 4.4, DeliveryFee: 25m, PrepTime: 15, Desc: "AC cafe with gallery space, perfect for afternoon heat escape."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000006"), Name: "The Turtles Cafe", Category: VendorCategory.Cafe, Cuisine: "Breakfast", Rating: 4.1, DeliveryFee: 25m, PrepTime: 15, Desc: "Bicycle-themed cafe famous for full English breakfast."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000007"), Name: "Pondy Pizzeria", Category: VendorCategory.Restaurant, Cuisine: "Italian", Rating: 4.0, DeliveryFee: 35m, PrepTime: 25, Desc: "Family-friendly pizzeria with wood-fired ovens."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000008"), Name: "Dragon Wok", Category: VendorCategory.Restaurant, Cuisine: "Chinese", Rating: 4.3, DeliveryFee: 40m, PrepTime: 20, Desc: "Authentic Sichuan and Cantonese wok dishes."),
            (Id: Guid.Parse("00000000-0000-0000-0000-000000000009"), Name: "Spice Route", Category: VendorCategory.Restaurant, Cuisine: "Indian", Rating: 4.4, DeliveryFee: 35m, PrepTime: 25, Desc: "Traditional South Indian thalis and Chettinad specials."),
            (Id: Guid.Parse("00000000-0000-0000-0000-00000000000a"), Name: "Shawarma Junction", Category: VendorCategory.Restaurant, Cuisine: "Street Food", Rating: 4.2, DeliveryFee: 20m, PrepTime: 10, Desc: "Quick shawarma rolls and falafel wraps, open late."),
            (Id: Guid.Parse("00000000-0000-0000-0000-00000000000b"), Name: "Brew & Bean", Category: VendorCategory.Cafe, Cuisine: "Cafe", Rating: 4.5, DeliveryFee: 20m, PrepTime: 10, Desc: "Specialty coffee roaster with fresh pastries and sandwiches."),
            (Id: Guid.Parse("00000000-0000-0000-0000-00000000000c"), Name: "Coastal Catch", Category: VendorCategory.Restaurant, Cuisine: "Seafood", Rating: 4.7, DeliveryFee: 50m, PrepTime: 30, Desc: "Fresh catch of the day grilled, fried, or curried.")
        };

        var newVendors = new List<Vendor>();
        foreach (var s in seedVendors)
        {
            if (await _context.Vendors.AnyAsync(v => v.Id == s.Id, cancellationToken))
                continue;

            var vendor = Vendor.CreateForSeed(
                s.Id, s.Name, s.Category,
                cuisineType: s.Cuisine, rating: s.Rating,
                description: s.Desc, deliveryFee: s.DeliveryFee,
                prepTimeMinutes: s.PrepTime);
            vendor.Approve();
            newVendors.Add(vendor);
        }

        if (newVendors.Count > 0)
        {
            _context.Vendors.AddRange(newVendors);
            await _context.SaveChangesAsync(cancellationToken);
        }

        // Seed menu items for each new vendor (skip if already has items)
        foreach (var s in seedVendors)
        {
            if (await _context.MenuItems.AnyAsync(m => m.VendorId == s.Id, cancellationToken))
                continue;

            var items = s.Name switch
            {
                "Satsanga Garden Kitchen" => new[]
                {
                    MenuItem.Create(s.Id, "Veg Thali", 220m, "Thali", description: "Assorted curries, rice, roti, dal, and dessert.", imageUrl: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400"),
                    MenuItem.Create(s.Id, "Chicken Chettinad", 280m, "Mains", description: "Spicy Tamil-style chicken curry.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1569058242253-92a9e75c47a9?w=400"),
                    MenuItem.Create(s.Id, "Paneer Butter Masala", 240m, "Mains", description: "Creamy tomato gravy with cottage cheese.", imageUrl: "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400"),
                    MenuItem.Create(s.Id, "Gulab Jamun (2 pc)", 80m, "Dessert", description: "Warm syrup-soaked dumplings.", imageUrl: "https://images.unsplash.com/photo-1601304549427-2e9c8f4b4b1f?w=400"),
                    MenuItem.Create(s.Id, "Masala Dosa", 120m, "South Indian", description: "Crispy rice crepe with potato filling.", imageUrl: "https://images.unsplash.com/photo-1668236970733-d2a5e4b7b8c3?w=400")
                },
                "La Maison Rose" => new[]
                {
                    MenuItem.Create(s.Id, "Coq au Vin", 450m, "Mains", description: "Braised chicken in red wine with mushrooms.", imageUrl: "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400"),
                    MenuItem.Create(s.Id, "Ratatouille", 320m, "Mains", description: "Provençal baked vegetables with herbs.", imageUrl: "https://images.unsplash.com/photo-1574484284002-953d92462f60?w=400"),
                    MenuItem.Create(s.Id, "French Onion Soup", 180m, "Starters", description: "Caramelized onions with croutons and cheese.", imageUrl: "https://images.unsplash.com/photo-1547592180-85f173990554?w=400"),
                    MenuItem.Create(s.Id, "Crème Brûlée", 200m, "Dessert", description: "Vanilla custard with caramelized sugar top.", imageUrl: "https://images.unsplash.com/photo-1470124182917-cc6e71b22944?w=400"),
                    MenuItem.Create(s.Id, "Quiche Lorraine", 220m, "Starters", description: "Savory tart with bacon and gruyère.", imageUrl: "https://images.unsplash.com/photo-1631108306864-496a0f4a39c0?w=400")
                },
                "Baker Street Bistro" => new[]
                {
                    MenuItem.Create(s.Id, "Butter Croissant", 60m, "Bakery", description: "Flaky buttery croissant baked fresh daily.", imageUrl: "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=400"),
                    MenuItem.Create(s.Id, "Chocolate Eclair", 90m, "Pastry", description: "Choux pastry filled with chocolate cream.", imageUrl: "https://images.unsplash.com/photo-1612203985729-70726954388c?w=400"),
                    MenuItem.Create(s.Id, "Quiche Vegetarian", 150m, "Savory", description: "Spinach and cheese quiche.", imageUrl: "https://images.unsplash.com/photo-1631108306864-496a0f4a39c0?w=400"),
                    MenuItem.Create(s.Id, "Cinnamon Roll", 80m, "Pastry", description: "Soft roll with cinnamon sugar glaze.", imageUrl: "https://images.unsplash.com/photo-1595435172879-2c8f4b4b8b3f?w=400"),
                    MenuItem.Create(s.Id, "Fresh Baguette", 50m, "Bakery", description: "Crusty French baguette, baked in-house.", imageUrl: "https://images.unsplash.com/photo-1597079910443-6c15d4b9b4b2?w=400")
                },
                "Café des Arts" => new[]
                {
                    MenuItem.Create(s.Id, "Cappuccino", 90m, "Coffee", description: "Espresso with steamed milk and foam.", imageUrl: "https://images.unsplash.com/photo-1572442388796-11668a67e63d?w=400"),
                    MenuItem.Create(s.Id, "Cold Brew", 120m, "Coffee", description: "12-hour steeped cold coffee.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400"),
                    MenuItem.Create(s.Id, "Club Sandwich", 180m, "Sandwiches", description: "Triple-decker with chicken, egg, and veggies.", imageUrl: "https://images.unsplash.com/photo-1528740561666-dc2479dc08ab?w=400"),
                    MenuItem.Create(s.Id, "Veg Wrap", 140m, "Sandwiches", description: "Grilled vegetables in a whole wheat wrap.", imageUrl: "https://images.unsplash.com/photo-1626700051175-6818013ad1a8?w=400"),
                    MenuItem.Create(s.Id, "Brownie with Ice Cream", 160m, "Dessert", description: "Warm fudge brownie with vanilla ice cream.", imageUrl: "https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400")
                },
                "The Turtles Cafe" => new[]
                {
                    MenuItem.Create(s.Id, "Full English Breakfast", 250m, "Breakfast", description: "Eggs, bacon, sausage, beans, toast, and hash browns.", imageUrl: "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400"),
                    MenuItem.Create(s.Id, "Pancake Stack", 180m, "Breakfast", description: "Fluffy pancakes with maple syrup and butter.", imageUrl: "https://images.unsplash.com/photo-1567620905720-1372c9c8c4ad?w=400"),
                    MenuItem.Create(s.Id, "Eggs Benedict", 220m, "Breakfast", description: "Poached eggs on English muffins with hollandaise.", imageUrl: "https://images.unsplash.com/photo-1608039759621-1e5b1c3670a3?w=400"),
                    MenuItem.Create(s.Id, "Filter Coffee", 60m, "Beverages", description: "South Indian style filter coffee.", imageUrl: "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400"),
                    MenuItem.Create(s.Id, "Avocado Toast", 160m, "Breakfast", description: "Smashed avocado on sourdough with chili flakes.", imageUrl: "https://images.unsplash.com/photo-1541519227354-08fa5a50a504?w=400")
                },
                "Pondy Pizzeria" => new[]
                {
                    MenuItem.Create(s.Id, "Margherita Pizza", 250m, "Pizza", description: "Classic tomato, mozzarella, and basil.", imageUrl: "https://images.unsplash.com/photo-1574071318508-1cdbab80b25f?w=400"),
                    MenuItem.Create(s.Id, "Veg Supreme Pizza", 320m, "Pizza", description: "Bell peppers, onions, mushrooms, olives.", imageUrl: "https://images.unsplash.com/photo-1574071318508-1cdbab80b25f?w=400"),
                    MenuItem.Create(s.Id, "Chicken Tikka Pizza", 380m, "Pizza", description: "Tandoori chicken with peppers and mint mayo.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1593564705826-36b9403c0c66?w=400"),
                    MenuItem.Create(s.Id, "Garlic Knots (6 pc)", 100m, "Sides", description: "Soft dough knots with garlic butter.", imageUrl: "https://images.unsplash.com/photo-1573140246462-332f2d2b4c91?w=400"),
                    MenuItem.Create(s.Id, "Choco Lava Cake", 120m, "Dessert", description: "Warm chocolate cake with molten center.", imageUrl: "https://images.unsplash.com/photo-1606313562571-483c5b9c6c4c?w=400")
                },
                "Dragon Wok" => new[]
                {
                    MenuItem.Create(s.Id, "Kung Pao Chicken", 280m, "Mains", description: "Spicy stir-fried chicken with peanuts.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1525755662778-989d4823f364?w=400"),
                    MenuItem.Create(s.Id, "Veg Hakka Noodles", 180m, "Noodles", description: "Wok-tossed noodles with vegetables.", imageUrl: "https://images.unsplash.com/photo-1612929633738-8e90e9c3b9da?w=400"),
                    MenuItem.Create(s.Id, "Chilli Paneer", 240m, "Mains", description: "Indo-Chinese paneer in spicy sauce.", imageUrl: "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400"),
                    MenuItem.Create(s.Id, "Spring Rolls (4 pc)", 120m, "Starters", description: "Crispy rolls with veggie filling.", imageUrl: "https://images.unsplash.com/photo-1606851090710-3c9b8b0b3b3b?w=400"),
                    MenuItem.Create(s.Id, "Schezwan Fried Rice", 200m, "Rice", description: "Spicy fried rice with schezwan sauce.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400"),
                    MenuItem.Create(s.Id, "Wonton Soup", 150m, "Soups", description: "Pork wontons in clear broth.", imageUrl: "https://images.unsplash.com/photo-1547592180-85f173990554?w=400")
                },
                "Spice Route" => new[]
                {
                    MenuItem.Create(s.Id, "Chettinad Chicken Biryani", 300m, "Biryani", description: "Spicy Chettinad-style biryani with raita.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400"),
                    MenuItem.Create(s.Id, "Mutton Pepper Fry", 350m, "Mains", description: "Dry mutton curry with black pepper.", imageUrl: "https://images.unsplash.com/photo-1606491956687-8e76de41a91e?w=400"),
                    MenuItem.Create(s.Id, "Fish Moilee", 320m, "Mains", description: "Kerala-style fish curry in coconut milk.", imageUrl: "https://images.unsplash.com/photo-1531750026848-8ada13a40d8a?w=400"),
                    MenuItem.Create(s.Id, "Rasam", 60m, "Soups", description: "Tangy spiced tamarind soup.", imageUrl: "https://images.unsplash.com/photo-1606491956687-8e76de41a91e?w=400"),
                    MenuItem.Create(s.Id, "Payasam", 80m, "Dessert", description: "Traditional rice and milk pudding.", imageUrl: "https://images.unsplash.com/photo-1601304549427-2e9c8f4b4b1f?w=400")
                },
                "Shawarma Junction" => new[]
                {
                    MenuItem.Create(s.Id, "Chicken Shawarma Roll", 120m, "Shawarma", description: "Rolled shawarma with garlic sauce.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1639024471283-03518883512d?w=400"),
                    MenuItem.Create(s.Id, "Falafel Wrap", 100m, "Wraps", description: "Crispy falafel with hummus and veggies.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1626700051175-6818013ad1a8?w=400"),
                    MenuItem.Create(s.Id, "Chicken Shawarma Plate", 180m, "Plates", description: "Shawarma with rice, salad, and pita.", imageUrl: "https://images.unsplash.com/photo-1595940814762-2c9c0b4b4b3f?w=400"),
                    MenuItem.Create(s.Id, "Hummus & Pita", 80m, "Sides", description: "Creamy hummus with warm pita bread.", imageUrl: "https://images.unsplash.com/photo-1571197119282-8c4b4b4b4b4b?w=400")
                },
                "Brew & Bean" => new[]
                {
                    MenuItem.Create(s.Id, "Flat White", 100m, "Coffee", description: "Double shot ristretto with steamed milk.", imageUrl: "https://images.unsplash.com/photo-1572442388796-11668a67e63d?w=400"),
                    MenuItem.Create(s.Id, "Iced Latte", 130m, "Coffee", description: "Chilled espresso with cold milk.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400"),
                    MenuItem.Create(s.Id, "Veg Puff", 40m, "Snacks", description: "Flaky pastry with spicy vegetable filling.", imageUrl: "https://images.unsplash.com/photo-1605278286492-3c8b4b4b4b4b?w=400"),
                    MenuItem.Create(s.Id, "Egg Puff", 50m, "Snacks", description: "Flaky pastry with spiced egg filling.", imageUrl: "https://images.unsplash.com/photo-1605278286492-3c8b4b4b4b4b?w=400"),
                    MenuItem.Create(s.Id, "Cold Coffee", 120m, "Coffee", description: "Blended iced coffee with ice cream.", isLateNight: true, imageUrl: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400")
                },
                "Coastal Catch" => new[]
                {
                    MenuItem.Create(s.Id, "Grilled Sea Bass", 480m, "Grilled", description: "Whole sea bass grilled with herbs and lemon butter.", imageUrl: "https://images.unsplash.com/photo-1535140728325-a4d3707eee84?w=400"),
                    MenuItem.Create(s.Id, "Fish & Chips", 320m, "Fried", description: "Beer-battered fish with fries and tartar sauce.", imageUrl: "https://images.unsplash.com/photo-1535140728325-a4d3707eee84?w=400"),
                    MenuItem.Create(s.Id, "Prawn Curry", 380m, "Curry", description: "Fresh prawns in coconut masala.", imageUrl: "https://images.unsplash.com/photo-1531750026848-8ada13a40d8a?w=400"),
                    MenuItem.Create(s.Id, "Calamari Rings", 220m, "Starters", description: "Crispy fried squid rings with dip.", imageUrl: "https://images.unsplash.com/photo-1599909366516-6c4b4b4b4b4b?w=400"),
                    MenuItem.Create(s.Id, "Crab Masala", 420m, "Curry", description: "Crab cooked in spicy Chettinad masala.", imageUrl: "https://images.unsplash.com/photo-1606491956687-8e76de41a91e?w=400")
                },
                _ => Array.Empty<MenuItem>()
            };

            if (items.Length > 0)
            {
                _context.MenuItems.AddRange(items);
                await _context.SaveChangesAsync(cancellationToken);
            }
        }
    }

    private async Task SeedProductsAsync(CancellationToken cancellationToken)
    {
        if (await _context.Products.AnyAsync(cancellationToken))
            return;

        var products = new[]
        {
            // ── Hydration & Recovery ──
            Product.Create("Hydration Salts (ORS)", 50m, ProductCategory.HydrationRecovery, "Electrolytes", stockCount: 100, description: "Orange flavor hydration salt sachet.", isLateNightEssential: true),
            Product.Create("Coconut Water 200ml", 40m, ProductCategory.HydrationRecovery, "Natural Drinks", stockCount: 50, brand: "Tender", isLateNightEssential: true),
            Product.Create("Energy Drink 250ml", 80m, ProductCategory.HydrationRecovery, "Energy Drinks", stockCount: 60, brand: "Sting", description: "Caffeine and taurine energy boost.", isLateNightEssential: true),
            // ── Smoking Accessories ──
            Product.Create("Slimjim Rolling Papers", 120m, ProductCategory.SmokingAccessories, "Rolling Papers", stockCount: 80, brand: "Slimjim", isLateNightEssential: true),
            Product.Create("Slimjim Filter Tips", 60m, ProductCategory.SmokingAccessories, "Filter Tips", stockCount: 60, brand: "Slimjim", isLateNightEssential: true),
            Product.Create("Stash-Pro Grinder", 220m, ProductCategory.SmokingAccessories, "Grinders", stockCount: 30, brand: "Stash-Pro", isLateNightEssential: true),
            // ── Beach Essentials ──
            Product.Create("Sunscreen SPF 50", 180m, ProductCategory.BeachEssentials, "Sun Protection", stockCount: 40, brand: "Neutrogena"),
            Product.Create("Beach Towel", 250m, ProductCategory.BeachEssentials, "Towels", stockCount: 25),
            Product.Create("Beach Hat", 150m, ProductCategory.BeachEssentials, "Accessories", stockCount: 20, description: "Wide-brim sun hat."),
            Product.Create("Sunglasses", 200m, ProductCategory.BeachEssentials, "Accessories", stockCount: 15, description: "UV400 polarized sunglasses."),
            // ── Snacks ──
            Product.Create("Mixed Nuts Pack", 120m, ProductCategory.Snacks, "Trail Mix", stockCount: 70, isLateNightEssential: true),
            Product.Create("Instant Noodles", 30m, ProductCategory.Snacks, "Instant Food", stockCount: 100, isLateNightEssential: true),
            // ── Misc ──
            Product.Create("Disposable Lighter", 20m, ProductCategory.Misc, "Lighters", stockCount: 120, isLateNightEssential: true)
        };

        _context.Products.AddRange(products);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedDriversAsync(CancellationToken cancellationToken)
    {
        if (await _context.Drivers.AnyAsync(cancellationToken))
            return;

        var driverUser1 = User.Create("Suresh Kumar", "9000000050", UserRole.Driver);
        var driverUser2 = User.Create("Deepak Raj", "9000000051", UserRole.Driver);
        var driverUser3 = User.Create("Arun Pandi", "9000000052", UserRole.Driver);
        var driverUser4 = User.Create("Karthik S", "9000000053", UserRole.Driver);
        var driverUser5 = User.Create("Ramesh P", "9000000054", UserRole.Driver);
        _context.Users.AddRange(driverUser1, driverUser2, driverUser3, driverUser4, driverUser5);
        await _context.SaveChangesAsync(cancellationToken);

        var drivers = new[]
        {
            Driver.Create(driverUser1.Id, "Suresh Kumar", "9000000050", VehicleType.Bike, "PY-01-AB-1234"),
            Driver.Create(driverUser2.Id, "Deepak Raj", "9000000051", VehicleType.Auto, "PY-01-CD-5678"),
            Driver.Create(driverUser3.Id, "Arun Pandi", "9000000052", VehicleType.Bike, "PY-01-EF-9012"),
            Driver.Create(driverUser4.Id, "Karthik S", "9000000053", VehicleType.Bike, "PY-01-GH-3456"),
            Driver.Create(driverUser5.Id, "Ramesh P", "9000000054", VehicleType.Car, "PY-01-IJ-7890")
        };

        // Scatter drivers around Pondicherry landmarks for realistic E2E testing
        drivers[0].UpdateLocation(GeoLocation.Create(11.9390, 79.8350));  // Bus Stand
        drivers[1].UpdateLocation(GeoLocation.Create(11.9349, 79.8362));  // Promenade
        drivers[2].UpdateLocation(GeoLocation.Create(11.9356, 79.8301));  // White Town center
        drivers[3].UpdateLocation(GeoLocation.Create(11.9350, 79.8300));  // Rock Beach
        drivers[4].UpdateLocation(GeoLocation.Create(11.9368, 79.8325));  // Mission Street

        foreach (var driver in drivers)
        {
            driver.Approve();
            driver.GoOnline();
            // Complete tutorial and sign agreement so the Flutter router
            // routes seeded drivers directly to the dashboard instead of
            // redirecting them to the tutorial screen.
            driver.CompleteTutorial();
            driver.SignAgreement();
        }

        _context.Drivers.AddRange(drivers);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedFlashPromosAsync(CancellationToken cancellationToken)
    {
        var fuocoVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        if (await _context.VendorPromotions.AnyAsync(p => p.VendorId == fuocoVendorId && p.PromoType == PromoType.FlashSale, cancellationToken))
            return;

        var now = DateTimeOffset.UtcNow;

        var activePromo = VendorPromotion.Create(
            vendorId: fuocoVendorId,
            promoType: PromoType.FlashSale,
            title: "Fuoco Late Night 30% Off",
            cost: 0m,
            startsAt: now,
            expiresAt: now.AddHours(2),
            description: "30% off all late-night pizzas and shawarma!",
            discountPercentage: 30m);

        var expiredPromo = VendorPromotion.Create(
            vendorId: fuocoVendorId,
            promoType: PromoType.FlashSale,
            title: "Fuoco Lunch Special 50% Off",
            cost: 0m,
            startsAt: now.AddHours(-3),
            expiresAt: now.AddMinutes(-30),
            description: "Expired lunch flash sale.",
            discountPercentage: 50m);
        expiredPromo.Deactivate();

        _context.VendorPromotions.AddRange(activePromo, expiredPromo);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedTestPassesAsync(CancellationToken cancellationToken)
    {
        if (await _context.ServiceBookings.AnyAsync(b => b.Notes == "SEED-TEST-PASS", cancellationToken))
            return;

        var testUser = await _context.Users.FirstOrDefaultAsync(u => u.Phone == "9000000099", cancellationToken);
        if (testUser is null)
        {
            testUser = User.Create("Test Tourist", "9000000099", UserRole.Tourist);
            _context.Users.Add(testUser);
            await _context.SaveChangesAsync(cancellationToken);
        }

        var fuocoVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var scheduledFor = DateTimeOffset.UtcNow.AddDays(1);

        var venue = await _context.Venues.FirstOrDefaultAsync(v => v.Name == "Le Club", cancellationToken);
        var venueId = venue?.Id;

        if (venue is not null)
            venue.IncreaseOccupancy(2);

        var booking1 = ServiceBooking.Create(
            testUser.Id,
            ServiceType.Nightlife,
            scheduledFor,
            vendorId: fuocoVendorId,
            amount: 500m,
            notes: "SEED-TEST-PASS",
            venueId: venueId,
            seatCount: 2);
        booking1.AddItem("Venue cover charge", 2, 250m);
        booking1.Confirm();
        booking1.RecordPayment(PaymentStatus.Captured, "SEED-PAYMENT-001");

        var booking2 = ServiceBooking.Create(
            testUser.Id,
            ServiceType.Luggage,
            scheduledFor,
            vendorId: fuocoVendorId,
            amount: 80m,
            notes: "SEED-TEST-PASS");
        booking2.AddItem("Luggage cloak 24h", 1, 80m);
        booking2.Confirm();
        booking2.RecordPayment(PaymentStatus.Captured, "SEED-PAYMENT-002");

        _context.ServiceBookings.AddRange(booking1, booking2);
        await _context.SaveChangesAsync(cancellationToken);

        var pass1 = PassIssuer.Issue(booking1.Id, booking1.TotalAmount, booking1.ScheduledFor);
        booking1.IssuePassToken(pass1);
        var pass2 = PassIssuer.Issue(booking2.Id, booking2.TotalAmount, booking2.ScheduledFor);
        booking2.IssuePassToken(pass2);
        await _context.SaveChangesAsync(cancellationToken);

        var bundle = BundleBooking.Create(
            testUser.Id,
            "Long Weekend Pass (3 Days)",
            totalPrice: 730m,
            discountedPrice: 584m,
            description: "All-in-one pass: scooter rental, luggage cloak, venue entry, and transit pickup.",
            expiresAt: DateTimeOffset.UtcNow.AddDays(3),
            passType: PassType.WeekendPass);

        _context.BundleBookings.Add(bundle);
        await _context.SaveChangesAsync(cancellationToken);

        var passToken = WeekendPassIssuer.Issue(bundle.Id, testUser.Id, bundle.ExpiresAt!.Value);
        bundle.IssuePass(passToken);
        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedVendorCreditAsync(CancellationToken cancellationToken)
    {
        var fuocoVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == fuocoVendorId, cancellationToken);
        if (vendor is not null && vendor.CreditBalance == 0m)
        {
            vendor.TopUpCredit(5000m);
            await _context.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task SeedDriverKycAndLedgerAsync(CancellationToken cancellationToken)
    {
        if (await _context.DriverLedgerEntries.AnyAsync(cancellationToken))
            return;

        var drivers = await _context.Drivers.ToListAsync(cancellationToken);

        foreach (var driver in drivers)
        {
            if (!driver.IsKycUploaded)
            {
                driver.UploadKyc(
                    $"https://example.com/kyc/{driver.Id}/aadhaar.jpg",
                    $"https://example.com/kyc/{driver.Id}/dl.jpg",
                    $"https://example.com/kyc/{driver.Id}/rc.jpg",
                    $"driver{driver.Phone}@upi");
            }
        }

        await _context.SaveChangesAsync(cancellationToken);

        if (drivers.Count > 0)
        {
            var firstDriver = drivers[0];
            _context.DriverLedgerEntries.AddRange(
                DriverLedgerEntry.Create(firstDriver.Id, 250m, LedgerTransactionType.Earning, "SEED-RIDE-001"),
                DriverLedgerEntry.Create(firstDriver.Id, 180m, LedgerTransactionType.Earning, "SEED-FOOD-001"),
                DriverLedgerEntry.Create(firstDriver.Id, 50m, LedgerTransactionType.Bonus, "SEED-LATE-NIGHT-BONUS"),
                DriverLedgerEntry.Create(firstDriver.Id, 120m, LedgerTransactionType.Earning, "SEED-RIDE-002"));

            if (drivers.Count > 1)
            {
                var secondDriver = drivers[1];
                _context.DriverLedgerEntries.AddRange(
                    DriverLedgerEntry.Create(secondDriver.Id, 150m, LedgerTransactionType.Earning, "SEED-RIDE-003"),
                    DriverLedgerEntry.Create(secondDriver.Id, 40m, LedgerTransactionType.Earning, "SEED-FOOD-002"));
            }

            if (drivers.Count > 2)
            {
                var thirdDriver = drivers[2];
                _context.DriverLedgerEntries.AddRange(
                    DriverLedgerEntry.Create(thirdDriver.Id, 200m, LedgerTransactionType.Earning, "SEED-RIDE-004"),
                    DriverLedgerEntry.Create(thirdDriver.Id, 90m, LedgerTransactionType.Earning, "SEED-FOOD-003"),
                    DriverLedgerEntry.Create(thirdDriver.Id, 30m, LedgerTransactionType.Bonus, "SEED-PEAK-HOUR-BONUS"));
            }

            if (drivers.Count > 3)
            {
                var fourthDriver = drivers[3];
                _context.DriverLedgerEntries.AddRange(
                    DriverLedgerEntry.Create(fourthDriver.Id, 175m, LedgerTransactionType.Earning, "SEED-RIDE-005"),
                    DriverLedgerEntry.Create(fourthDriver.Id, 60m, LedgerTransactionType.Earning, "SEED-ESSENTIALS-001"));
            }

            if (drivers.Count > 4)
            {
                var fifthDriver = drivers[4];
                _context.DriverLedgerEntries.AddRange(
                    DriverLedgerEntry.Create(fifthDriver.Id, 320m, LedgerTransactionType.Earning, "SEED-RIDE-006"),
                    DriverLedgerEntry.Create(fifthDriver.Id, 45m, LedgerTransactionType.Earning, "SEED-FOOD-004"));
            }

            await _context.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task SeedHomestaysAsync(CancellationToken cancellationToken)
    {
        if (await _context.Homestays.AnyAsync(cancellationToken))
            return;

        var firstUser = await _context.Users.FirstOrDefaultAsync(cancellationToken);
        if (firstUser is null)
            return;

        var homestays = new[]
        {
            Homestay.Create(
                firstUser.Id,
                "La Maison Blanche",
                "A heritage French colonial villa in the heart of White Town with high ceilings, vintage furniture, and a private courtyard garden.",
                "White Town",
                11.9362, 79.8346,
                nightlyRate: 2500m,
                maxGuests: 4,
                hasWifi: true),
            Homestay.Create(
                firstUser.Id,
                "Auroville Forest Retreat",
                "Eco-friendly bamboo cottage surrounded by tropical forest. Perfect for digital nomads with high-speed internet and a serene workspace.",
                "Auroville",
                12.0050, 79.8100,
                nightlyRate: 1800m,
                maxGuests: 2,
                hasWifi: true),
            Homestay.Create(
                firstUser.Id,
                "Rock Beach Sea View Studio",
                "Modern studio apartment with panoramic views of the Bay of Bengal. Step out directly onto the promenade.",
                "Rock Beach",
                11.9350, 79.8300,
                nightlyRate: 3200m,
                maxGuests: 3,
                hasWifi: true),
            Homestay.Create(
                firstUser.Id,
                "French Quarter Heritage Home",
                "Restored 19th-century Tamil-French home with traditional courtyard, antique decor, and modern amenities in the charming French Quarter.",
                "French Quarter",
                11.9380, 79.8360,
                nightlyRate: 2800m,
                maxGuests: 6,
                hasWifi: false)
        };

        foreach (var homestay in homestays)
            homestay.Verify();

        _context.Homestays.AddRange(homestays);
        await _context.SaveChangesAsync(cancellationToken);

        var today = DateOnly.FromDateTime(DateTimeOffset.UtcNow.Date);
        foreach (var homestay in homestays)
        {
            var availability = new List<RoomAvailability>();
            for (var i = 0; i < 30; i++)
            {
                var date = today.AddDays(i);
                availability.Add(RoomAvailability.Create(homestay.Id, date));
            }

            if (homestay.Name == "La Maison Blanche")
            {
                availability[5].Lock(Guid.NewGuid());
                availability[6].Lock(Guid.NewGuid());
            }

            _context.RoomAvailabilities.AddRange(availability);
        }

        await _context.SaveChangesAsync(cancellationToken);
    }

    private async Task SeedSupportTicketsAsync(CancellationToken cancellationToken)
    {
        if (await _context.SupportTickets.AnyAsync(cancellationToken))
            return;

        var firstUser = await _context.Users.FirstOrDefaultAsync(cancellationToken);
        if (firstUser is null)
            return;

        var ticket1 = SupportTicket.Create(
            firstUser.Id,
            TicketPriority.Normal,
            TicketSource.InApp);
        ticket1.MarkInProgress();

        var ticket2 = SupportTicket.Create(
            firstUser.Id,
            TicketPriority.Critical,
            TicketSource.SOS,
            latitude: 11.9356,
            longitude: 79.8301,
            issueCategory: "Scooter Breakdown");
        ticket2.Escalate();

        _context.SupportTickets.AddRange(ticket1, ticket2);
        await _context.SaveChangesAsync(cancellationToken);

        _context.TicketMessages.AddRange(
            TicketMessage.Create(ticket1.Id, MessageSenderRole.User, "How do I cancel my booking?"),
            TicketMessage.Create(ticket1.Id, MessageSenderRole.AI, "I can help you cancel your booking. Please share your booking ID and I'll process the cancellation."),
            TicketMessage.Create(ticket2.Id, MessageSenderRole.User, "SOS: Scooter Breakdown"));

        await _context.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Seeds a PartySupplier (equipment rental) vendor with sample inventory
    /// so the Partner app can demonstrate the equipment ecosystem workflow.
    /// Vendor phone: 9000000020 (owner user created if missing).
    /// </summary>
    private async Task SeedPartySupplierAsync(CancellationToken cancellationToken)
    {
        if (await _context.EquipmentItems.AnyAsync(cancellationToken))
            return;

        var phone = "9000000020";

        // Create owner user if it doesn't exist
        if (!await _context.Users.AnyAsync(u => u.Phone == phone, cancellationToken))
        {
            _context.Users.Add(User.Create("Pondy AV Owner", phone, UserRole.Vendor));
            await _context.SaveChangesAsync(cancellationToken);
        }

        // Create the vendor if it doesn't exist
        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.ContactPhone == phone, cancellationToken);
        if (vendor is null)
        {
            vendor = Vendor.Create("Pondy AV Rentals", VendorCategory.PartySupplier, contactPhone: phone, description: "Audio-visual equipment rentals for private events. Speakers, lights, smoke machines.");
            vendor.Approve();
            _context.Vendors.Add(vendor);
            await _context.SaveChangesAsync(cancellationToken);
        }

        // Seed sample equipment inventory
        var equipment = new[]
        {
            EquipmentItem.Create(vendor.Id, "JBL PartyBox 310", 1500m, 5000m, 4, "Speakers", "Portable party speaker with deep bass and light show.", null),
            EquipmentItem.Create(vendor.Id, "JBL PartyBox 710", 3000m, 10000m, 2, "Speakers", "High-power party speaker with karaoke and guitar inputs.", null),
            EquipmentItem.Create(vendor.Id, "LED Par Wash Lights (Set of 4)", 800m, 3000m, 5, "Lighting", "RGB LED par cans with DMX controller for event lighting.", null),
            EquipmentItem.Create(vendor.Id, "Smoke/Fog Machine 700W", 500m, 2000m, 3, "Effects", "Compact fog machine with wired remote for atmosphere effects.", null),
            EquipmentItem.Create(vendor.Id, "Wireless Microphone Set (2)", 600m, 2500m, 6, "Audio", "UHF wireless mic system with receiver, ideal for hosts and DJs.", null),
            EquipmentItem.Create(vendor.Id, "DJ Controller Deck", 2000m, 8000m, 2, "DJ Equipment", "2-channel DJ controller with USB audio interface.", null),
        };

        _context.EquipmentItems.AddRange(equipment);
        await _context.SaveChangesAsync(cancellationToken);
    }
}