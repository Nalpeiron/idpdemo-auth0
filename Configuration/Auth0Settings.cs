namespace IdpDemo.Configuration;

public sealed class Auth0Settings
{
	public string Domain { get; init; } = string.Empty;

	public string ClientId { get; init; } = string.Empty;

	public string RedirectUri { get; init; } = "idpdemo://callback";

	public string PostLogoutRedirectUri { get; init; } = "idpdemo://callback";

	public string Scope { get; init; } = "openid profile email offline_access";

	public string ClaimNamespace { get; init; } = "https://idpdemo.example.com/auth0";

	public string EntitlementGroupIdClaim { get; init; } = "urn:nalpeiron:zentitle2:claims:entitlement_group_ids";

	public string RolesClaim { get; init; } = "https://idpdemo.example.com/auth0/roles";

	public string RequiredRoleName { get; init; } = string.Empty;

	public bool IsConfigured() =>
		!string.IsNullOrWhiteSpace(Domain) &&
		!string.IsNullOrWhiteSpace(ClientId) &&
		!Domain.Contains("your-auth0-domain", StringComparison.OrdinalIgnoreCase) &&
		!ClientId.Contains("your-auth0-client-id", StringComparison.OrdinalIgnoreCase);
}
