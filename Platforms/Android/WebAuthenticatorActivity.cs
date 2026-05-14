using Android.App;
using Android.Content;
using Android.Content.PM;

namespace IdpDemo;

[Activity(NoHistory = true, LaunchMode = LaunchMode.SingleTop, Exported = true, Theme = "@style/Maui.SplashTheme")]
[IntentFilter(
	new[] { Intent.ActionView },
	Categories = new[] { Intent.CategoryDefault, Intent.CategoryBrowsable },
	DataScheme = CallbackScheme)]
public class WebAuthenticatorActivity : Microsoft.Maui.Authentication.WebAuthenticatorCallbackActivity
{
	private const string CallbackScheme = "idpdemo";
}
