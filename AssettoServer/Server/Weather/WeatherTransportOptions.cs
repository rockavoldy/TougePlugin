namespace AssettoServer.Server.Weather;

/// <summary>
/// Selects how weather is delivered to clients.
/// </summary>
/// <remarks>
/// This is deliberately not bound to <c>extra_cfg.yml</c>: existing server configurations keep working
/// unchanged and pick up the default automatically.
/// </remarks>
public class WeatherTransportOptions
{
    /// <summary>
    /// When true, CSP conditions V2 (client message 1001) is sent, which includes rain intensity, wetness
    /// and puddle depth. When false, the smaller V1 packet (client message 1000) is sent.
    /// </summary>
    public bool UseConditionsV2 { get; init; } = true;
}
