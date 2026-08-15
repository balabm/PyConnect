namespace PondyConnect.Application.Features.QuickCommerce;

using PondyConnect.Domain.Enums;

/// <summary>
/// Suggests complementary products for bundle optimization.
/// </summary>
public static class ProductCartService
{
    private static readonly Dictionary<ProductCategory, ProductCategory[]> BundleMap = new()
    {
        [ProductCategory.SmokingAccessories] = [ProductCategory.Snacks, ProductCategory.Misc],
        [ProductCategory.HydrationRecovery] = [ProductCategory.Snacks, ProductCategory.BeachEssentials],
        [ProductCategory.BeachEssentials] = [ProductCategory.HydrationRecovery, ProductCategory.Misc],
        [ProductCategory.Snacks] = [ProductCategory.HydrationRecovery],
        [ProductCategory.Misc] = [ProductCategory.Snacks]
    };

    public static IEnumerable<ProductCategory> GetSuggestedCategories(ProductCategory category)
    {
        if (BundleMap.TryGetValue(category, out var suggestions))
            return suggestions;
        return [];
    }

    public static IEnumerable<ProductCategory> GetSuggestedCategories(IEnumerable<ProductCategory> cartCategories)
    {
        var result = new HashSet<ProductCategory>();
        foreach (var cat in cartCategories)
        {
            foreach (var suggested in GetSuggestedCategories(cat))
            {
                if (!cartCategories.Contains(suggested))
                    result.Add(suggested);
            }
        }
        return result;
    }
}
