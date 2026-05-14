namespace IdpDemo.Configuration;

public static class AppSettingsValidator
{
	public static string? Validate(AppSettings settings)
	{
		if (string.IsNullOrWhiteSpace(settings.Auth0.Domain) ||
			settings.Auth0.Domain.Contains("your-auth0-domain", StringComparison.OrdinalIgnoreCase))
		{
			return "Auth0.Domain is missing or still uses the placeholder value.";
		}

		if (string.IsNullOrWhiteSpace(settings.Auth0.ClientId) ||
			settings.Auth0.ClientId.Contains("your-auth0-client-id", StringComparison.OrdinalIgnoreCase))
		{
			return "Auth0.ClientId is missing or still uses the placeholder value.";
		}

		if (string.IsNullOrWhiteSpace(settings.Auth0.RedirectUri))
		{
			return "Auth0.RedirectUri is missing.";
		}

		if (string.IsNullOrWhiteSpace(settings.Zentitle2.IdpUrl) ||
			settings.Zentitle2.IdpUrl.Contains("your-auth0-domain", StringComparison.OrdinalIgnoreCase))
		{
			return "Zentitle2.IdpUrl is missing or still uses the placeholder value.";
		}

		if (string.IsNullOrWhiteSpace(settings.Zentitle2.TenantId))
		{
			return "Zentitle2.TenantId is missing.";
		}

		if (string.IsNullOrWhiteSpace(settings.Zentitle2.LicensingApiUrl))
		{
			return "Zentitle2.LicensingApiUrl is missing.";
		}

		if (string.IsNullOrWhiteSpace(settings.Zentitle2.ProductId))
		{
			return "Zentitle2.ProductId is missing.";
		}

		return null;
	}
}
