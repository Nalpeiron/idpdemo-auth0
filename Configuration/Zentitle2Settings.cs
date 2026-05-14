namespace IdpDemo.Configuration;

public sealed class Zentitle2Settings
{
	public string TenantId { get; init; } = string.Empty;

	public string LicensingApiUrl { get; init; } = string.Empty;

	public string ProductId { get; init; } = string.Empty;

	public string IdpUrl { get; init; } = "https://your-auth0-domain.auth0.com";

	public string UsernameClaim { get; init; } = "email";

	public string AuthenticationClaim { get; init; } = "sub";

	public string EntitlementGroupIdClaim { get; init; } = "urn:nalpeiron:zentitle2:claims:entitlement_group_ids";
}
