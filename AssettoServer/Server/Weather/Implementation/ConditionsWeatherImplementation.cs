using AssettoServer.Network.Tcp;
using AssettoServer.Shared.Network.Packets.Outgoing;
using NodaTime;
using Serilog;

namespace AssettoServer.Server.Weather.Implementation;

/// <summary>
/// Sends weather to clients as CSP conditions client messages (types 1000 / 1001) instead of the
/// legacy UDP <see cref="CSPWeatherUpdate"/> packet.
/// </summary>
/// <remarks>
/// <see cref="WeatherManager"/> stays the source of truth: it advances the transition, rain, wetness and
/// grip state at 1 Hz and then asks this implementation to deliver it. Sending conditions instead of the
/// UDP packet is what lets clients receive rain intensity, wetness and puddle depth.
/// </remarks>
public class ConditionsWeatherImplementation : IWeatherImplementation
{
    /// <summary>
    /// Conditions are sent once per <see cref="WeatherManager"/> update tick, so the client should reach the
    /// next state within roughly a second. This is only a hint for CSP.
    /// </summary>
    private const float TimeToApplySeconds = 1f;

    /// <summary>
    /// Feature advertised to clients for conditions V1 (client message 1000).
    /// </summary>
    private const string FeatureWeatherFxV1 = "WEATHERFX_V1";

    /// <summary>
    /// Feature advertised to clients for conditions V2 (client message 1001), which is what carries
    /// rain intensity, wetness and puddle depth.
    /// </summary>
    private const string FeatureWeatherFxV2 = "WEATHERFX_V2";

    private readonly EntryCarManager _entryCarManager;
    private readonly bool _useV2;

    public ConditionsWeatherImplementation(EntryCarManager entryCarManager, CSPFeatureManager cspFeatureManager, WeatherTransportOptions options)
    {
        _entryCarManager = entryCarManager;
        _useV2 = options.UseConditionsV2;

        // Advertise the feature matching the packet actually sent, otherwise V2 clients would be told
        // the server only speaks V1.
        cspFeatureManager.Add(new CSPFeature
        {
            Name = _useV2 ? FeatureWeatherFxV2 : FeatureWeatherFxV1,
            Mandatory = true
        });

        Log.Information("Sending weather to clients as CSP conditions {Version}", _useV2 ? "V2" : "V1");
    }

    public void SendWeather(WeatherData weather, ZonedDateTime dateTime, ACTcpClient? client = null)
    {
        var encoded = Serialize(weather, dateTime);

        if (client == null)
        {
            _entryCarManager.BroadcastPacket(new CSPWeatherConditions(encoded));
        }
        else
        {
            client.SendPacket(new CSPWeatherConditions(encoded));
        }
    }

    private string Serialize(WeatherData weather, ZonedDateTime dateTime)
    {
        var unixTimestamp = (ulong)dateTime.ToInstant().ToUnixTimeSeconds();
        var weatherType = CSPConditionsWeather.EncodeWeatherType(weather.Type.WeatherFxType);
        var upcomingWeatherType = CSPConditionsWeather.EncodeWeatherType(weather.UpcomingType.WeatherFxType);

        if (!_useV2)
        {
            // TransitionValue is stored as ushort 0-65535, scale it back to 0-1 for V1.
            return CSPConditionsWeather.EncodeV1(unixTimestamp,
                weatherType,
                upcomingWeatherType,
                weather.TransitionValue / (float)ushort.MaxValue,
                TimeToApplySeconds);
        }

        return CSPConditionsWeather.EncodeV2(unixTimestamp,
            weatherType,
            upcomingWeatherType,
            weather.TransitionValue,
            TimeToApplySeconds,
            weather.TemperatureAmbient,
            weather.TemperatureRoad,
            weather.TrackGrip,
            weather.Humidity,
            weather.WindDirection,
            weather.WindSpeed,
            weather.Pressure,
            weather.RainIntensity,
            weather.RainWetness,
            weather.RainWater);
    }
}
