using System.Security.Claims;
using System.Text.Json;
using Auth0.OidcClient;
using Duende.IdentityModel.OidcClient;
using IdpDemo.Configuration;
using IdpDemo.Services;

namespace IdpDemo;

public partial class MainPage : ContentPage
{
	private readonly Auth0Client _auth0Client;
	private readonly AppSettings _appSettings;
	private readonly ZentitleActivationService _zentitleActivationService;
	private bool _isAuthenticated;

	public MainPage(
		Auth0Client auth0Client,
		AppSettings appSettings,
		ZentitleActivationService zentitleActivationService)
	{
		_auth0Client = auth0Client;
		_appSettings = appSettings;
		_zentitleActivationService = zentitleActivationService;
		InitializeComponent();
		ResetActivationSummary();
		UpdateLoginButtonState();
	}

	private async void OnLoginClicked(object? sender, EventArgs e)
	{
		var activationStarted = false;
		string? activationToken = null;

		if (_isAuthenticated)
		{
			await LogoutAsync();
			return;
		}

		if (!_appSettings.Auth0.IsConfigured())
		{
			await DisplayAlertAsync(
				"Auth0 Not Configured",
				"Run scripts/setup-auth0.sh, then rebuild the app before attempting to log in.",
				"OK");
			return;
		}

		SetBusyState(true);

		try
		{
			var loginResult = await _auth0Client.LoginAsync();
			if (loginResult.IsError)
			{
				await DisplayAlertAsync("Login Failed", BuildLoginErrorMessage(loginResult), "OK");
				return;
			}

			activationToken = loginResult.IdentityToken;
			activationStarted = true;

			var activationSummary = await ActivateSeatAsync(loginResult);
			UpdateAuthenticatedIdentity(loginResult.User, loginResult.AccessToken, loginResult.IdentityToken);
			ShowActivationSummary(activationSummary);
		}
		catch (Exception ex)
		{
			ClearAuthenticatedIdentity(clearActivationDetails: !activationStarted);
			if (activationStarted)
			{
				ShowActivationFailure(ex.Message, activationToken);
			}

			await DisplayAlertAsync("Login Failed", ex.Message, "OK");
		}
		finally
		{
			SetBusyState(false);
		}
	}

	private async Task LogoutAsync()
	{
		SetBusyState(true);

		try
		{
			if (_isAuthenticated)
			{
				await _zentitleActivationService.DeactivateAsync();
			}

			await _auth0Client.LogoutAsync();
			ClearAuthenticatedIdentity();
		}
		catch (Exception ex)
		{
			await DisplayAlertAsync("Logout Failed", ex.Message, "OK");
		}
		finally
		{
			SetBusyState(false);
		}
	}

	private async void OnDeleteStoredActivationClicked(object? sender, EventArgs e)
	{
		try
		{
			var deleted = _zentitleActivationService.DeleteStoredActivation();
			ActivationDetailsLabel.Text = deleted
				? "Stored activation deleted. The next login will create a new activation."
				: "No stored activation was found.";
			ActivationSummaryCard.IsVisible = true;

			await DisplayAlertAsync(
				"Stored Activation",
				deleted ? "Stored activation deleted." : "No stored activation was found.",
				"OK");
		}
		catch (Exception ex)
		{
			await DisplayAlertAsync("Delete Stored Activation Failed", ex.Message, "OK");
		}
	}

	private void SetBusyState(bool isBusy)
	{
		LoginButton.IsEnabled = !isBusy;
		DeleteStoredActivationButton.IsEnabled = !isBusy;
		LoginActivityIndicator.IsVisible = isBusy;
		LoginActivityIndicator.IsRunning = isBusy;
	}

	private void UpdateAuthenticatedIdentity(ClaimsPrincipal user, string? accessToken = null, string? identityToken = null)
	{
		var name = FindJwtClaim(accessToken, "name")
			?? FindJwtClaim(identityToken, "name")
			?? FindClaim(user, "name")
			?? FindClaim(user, "nickname")
			?? "Unavailable";
		var email = FindJwtClaim(accessToken, "email")
			?? FindJwtClaim(identityToken, "email")
			?? FindClaim(user, "email")
			?? "Unavailable";
		var subject = FindJwtClaim(accessToken, _appSettings.Zentitle2.AuthenticationClaim)
			?? FindJwtClaim(identityToken, _appSettings.Zentitle2.AuthenticationClaim)
			?? FindClaim(user, _appSettings.Zentitle2.AuthenticationClaim)
			?? "Unavailable";
		var issuer = FindJwtClaim(accessToken, "iss")
			?? FindJwtClaim(identityToken, "iss")
			?? FindClaim(user, "iss")
			?? "Unavailable";
		var entitlementGroupId = FindJwtClaim(accessToken, _appSettings.Zentitle2.EntitlementGroupIdClaim)
			?? FindClaim(user, _appSettings.Zentitle2.EntitlementGroupIdClaim)
			?? FindJwtClaim(identityToken, _appSettings.Zentitle2.EntitlementGroupIdClaim)
			?? "Missing";
		var roles = FindJwtClaim(accessToken, _appSettings.Auth0.RolesClaim)
			?? FindJwtClaim(identityToken, _appSettings.Auth0.RolesClaim)
			?? FindClaim(user, _appSettings.Auth0.RolesClaim)
			?? "No roles claim returned";

		UserNameLabel.Text = $"Name: {name}";
		UserEmailLabel.Text = $"Email: {email}";
		UserSubjectLabel.Text = $"{_appSettings.Zentitle2.AuthenticationClaim}: {subject}";
		UserIssuerLabel.Text = $"iss: {issuer}";
		EntitlementGroupLabel.Text = $"{_appSettings.Zentitle2.EntitlementGroupIdClaim}: {entitlementGroupId}";
		RolesLabel.Text = $"{_appSettings.Auth0.RolesClaim}: {roles}";
		Grid.SetColumn(ActivationSummaryCard, 1);
		Grid.SetColumnSpan(ActivationSummaryCard, 1);
		IdentitySummaryCard.IsVisible = true;
		_isAuthenticated = true;
		UpdateLoginButtonState();
	}

	private void ClearAuthenticatedIdentity(bool clearActivationDetails = true)
	{
		UserNameLabel.Text = string.Empty;
		UserEmailLabel.Text = string.Empty;
		UserSubjectLabel.Text = string.Empty;
		UserIssuerLabel.Text = string.Empty;
		EntitlementGroupLabel.Text = string.Empty;
		RolesLabel.Text = string.Empty;
		Grid.SetColumn(ActivationSummaryCard, 0);
		Grid.SetColumnSpan(ActivationSummaryCard, 2);
		if (clearActivationDetails)
		{
			ResetActivationSummary();
		}

		IdentitySummaryCard.IsVisible = false;
		ActivationSummaryCard.IsVisible = true;
		_isAuthenticated = false;
		UpdateLoginButtonState();
	}

	private void ResetActivationSummary()
	{
		ActivationDetailsLabel.Text = "Sign in to view the current activation details.";
		ActivationSummaryCard.IsVisible = true;
	}

	private void ShowActivationFailure(string errorMessage, string? activationToken)
	{
		var details = new List<string>
		{
			"Activation failed:",
			ValueOrUnavailable(errorMessage)
		};

		if (!string.IsNullOrWhiteSpace(activationToken))
		{
			details.Add($"OpenID Token:\n{activationToken}");
		}

		ActivationDetailsLabel.Text = string.Join("\n\n", details);
		ActivationSummaryCard.IsVisible = true;
	}

	private void ShowActivationSummary(ActivationSummary activationSummary)
	{
		ActivationDetailsLabel.Text = activationSummary.ToDisplayText();
		ActivationSummaryCard.IsVisible = true;
	}

	private void UpdateLoginButtonState()
	{
		LoginButton.Text = _isAuthenticated ? "Logout" : "Login";
		SemanticProperties.SetHint(LoginButton, _isAuthenticated ? "Logs the current user out" : "Opens the login flow");
	}

	private async Task<ActivationSummary> ActivateSeatAsync(LoginResult loginResult)
	{
		if (string.IsNullOrWhiteSpace(loginResult.IdentityToken))
		{
			throw new InvalidOperationException("Auth0 did not return an identity token required for Zentitle2 activation.");
		}

		ValidateTokenForActivation(loginResult.IdentityToken);

		var seatName = FindClaim(loginResult.User, "email")
			?? FindClaim(loginResult.User, "name")
			?? FindClaim(loginResult.User, "sub")
			?? "IdpDemo Seat";

		return await _zentitleActivationService.ActivateAsync(loginResult.IdentityToken, seatName);
	}

	private string BuildLoginErrorMessage(LoginResult loginResult)
	{
		var details = new List<string>();

		if (!string.IsNullOrWhiteSpace(loginResult.Error))
		{
			details.Add(loginResult.Error);
		}

		if (!string.IsNullOrWhiteSpace(loginResult.ErrorDescription) &&
			!string.Equals(loginResult.ErrorDescription, loginResult.Error, StringComparison.Ordinal))
		{
			details.Add(loginResult.ErrorDescription);
		}

		return details.Count > 0 ? string.Join("\n\n", details) : "The Auth0 login request failed.";
	}

	private void ValidateTokenForActivation(string token)
	{
		if (!JwtClaimHasAnyValue(token, _appSettings.Zentitle2.UsernameClaim))
		{
			throw new InvalidOperationException(
				$"Auth0 identity token is missing username claim '{_appSettings.Zentitle2.UsernameClaim}'. Update the Auth0 post-login Action to add it to the identity token.");
		}
	}

	private static string? FindClaim(ClaimsPrincipal user, string claimType)
	{
		return user.FindFirst(claimType)?.Value;
	}

	private static string ValueOrUnavailable(string? value)
	{
		return string.IsNullOrWhiteSpace(value) ? "Unavailable" : value;
	}

	private static string? FindJwtClaim(string? token, string claimName)
	{
		var claimValues = FindJwtClaimValues(token, claimName);
		return claimValues.Count switch
		{
			0 => null,
			1 => claimValues[0],
			_ => string.Join(", ", claimValues)
		};
	}

	private static bool JwtClaimHasAnyValue(string? token, string claimName)
	{
		return FindJwtClaimValues(token, claimName).Any(value => !string.IsNullOrWhiteSpace(value));
	}

	private static IReadOnlyList<string> FindJwtClaimValues(string? token, string claimName)
	{
		if (string.IsNullOrWhiteSpace(token))
		{
			return Array.Empty<string>();
		}

		var parts = token.Split('.');
		if (parts.Length < 2)
		{
			return Array.Empty<string>();
		}

		try
		{
			var payloadBytes = DecodeBase64Url(parts[1]);
			using var document = JsonDocument.Parse(payloadBytes);

			if (!document.RootElement.TryGetProperty(claimName, out var claimValue))
			{
				return Array.Empty<string>();
			}

			return claimValue.ValueKind switch
			{
				JsonValueKind.Array => claimValue
					.EnumerateArray()
					.Select(FormatJwtClaimValue)
					.Where(value => !string.IsNullOrWhiteSpace(value))
					.Select(value => value!)
					.ToArray(),
				_ => FormatJwtClaimValue(claimValue) is { } value
					? new[] { value }
					: Array.Empty<string>()
			};
		}
		catch
		{
			return Array.Empty<string>();
		}
	}

	private static string? FormatJwtClaimValue(JsonElement claimValue)
	{
		return claimValue.ValueKind switch
		{
			JsonValueKind.Null => null,
			JsonValueKind.Undefined => null,
			JsonValueKind.String => claimValue.GetString(),
			_ => claimValue.ToString()
		};
	}

	private static byte[] DecodeBase64Url(string value)
	{
		var normalized = value.Replace('-', '+').Replace('_', '/');
		var padding = normalized.Length % 4;

		if (padding > 0)
		{
			normalized = normalized.PadRight(normalized.Length + (4 - padding), '=');
		}

		return Convert.FromBase64String(normalized);
	}
}
