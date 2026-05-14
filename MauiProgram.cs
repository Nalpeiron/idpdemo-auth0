using Auth0.OidcClient;
using IdpDemo.Configuration;
using IdpDemo.Services;
using Microsoft.Extensions.Logging;

namespace IdpDemo;

public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
		var configurationResult = AppSettingsLoader.Load();

		builder
			.UseMauiApp<App>()
			.ConfigureFonts(fonts =>
			{
				fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
				fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
			});

		builder.Services.AddSingleton(configurationResult);
		builder.Services.AddSingleton(sp =>
		{
			var loadResult = sp.GetRequiredService<ConfigurationLoadResult>();
			return loadResult.Settings ?? throw new InvalidOperationException(loadResult.ErrorMessage ?? "Application settings are unavailable.");
		});
		builder.Services.AddSingleton<ApplicationLifetimeService>();
		builder.Services.AddSingleton<ErrorPage>();
		builder.Services.AddSingleton<MainPage>();
		builder.Services.AddSingleton<ZentitleActivationService>();

		builder.Services.AddSingleton(sp =>
		{
			var loadResult = sp.GetRequiredService<ConfigurationLoadResult>();
			if (!loadResult.IsSuccess || loadResult.Settings is null)
			{
				throw new InvalidOperationException(loadResult.ErrorMessage ?? "Auth0 configuration is unavailable.");
			}

			var settings = loadResult.Settings.Auth0;
			return new Auth0Client(new Auth0ClientOptions
			{
				Domain = settings.Domain,
				ClientId = settings.ClientId,
				Scope = settings.Scope,
				RedirectUri = settings.RedirectUri,
				PostLogoutRedirectUri = settings.PostLogoutRedirectUri,
				LoggerFactory = sp.GetRequiredService<ILoggerFactory>()
			});
		});

#if DEBUG
		builder.Logging.AddDebug();
#endif

		return builder.Build();
	}
}
