namespace IdpDemo.Configuration;

public sealed class AppSettings
{
	public Auth0Settings Auth0 { get; init; } = new();

	public Zentitle2Settings Zentitle2 { get; init; } = new();
}
