using System.Buffers.Binary;
using AssettoServer.Shared.Network.Packets.Shared;
using AssettoServer.Shared.Weather;

namespace AssettoServer.Shared.Network.Packets.Outgoing;

/// <summary>
/// Serializes CSP weather conditions (client message types 1000 and 1001) into the chat encoded
/// <c>$CSP0:</c> envelope that CSP clients understand.
/// </summary>
/// <remarks>
/// This intentionally does not use <see cref="CSPClientMessageOutgoing"/>: that type respects the static
/// <c>ChatEncoded</c> flag which is disabled when client messages are enabled, while conditions are always
/// delivered through the chat envelope. The payload layout matches Sol/CSP:
/// <code>
/// V1: type(u16) timestamp(u64) current(u8) next(u8) transition(f32) timeToApply(f32)  = 20 bytes
/// V2: type(u16) timestamp(u64) current(u8) next(u8) transition(u16)
///     timeToApply, ambient, road (f16) grip(u8) humidity(u8)
///     windDir, windSpeed, pressure, rainIntensity, rainWetness, rainWater (f16)      = 34 bytes
/// </code>
/// All values are little endian, every float in V2 is IEEE-754 half precision.
/// </remarks>
public static class CSPConditionsWeather
{
    public const byte SenderId = 255;

    private const string ChatPrefix = "\t\t\t\t$CSP0:";

    private const int V1PayloadSize = 20;
    private const int V2PayloadSize = 34;

    public static string EncodeV1(ulong unixTimestamp,
        byte weatherType,
        byte upcomingWeatherType,
        float transition,
        float timeToApplySeconds)
    {
        Span<byte> payload = stackalloc byte[V1PayloadSize];

        BinaryPrimitives.WriteUInt16LittleEndian(payload, (ushort)CSPClientMessageType.ConditionsV1);
        BinaryPrimitives.WriteUInt64LittleEndian(payload[2..], unixTimestamp);
        payload[10] = weatherType;
        payload[11] = upcomingWeatherType;
        BinaryPrimitives.WriteSingleLittleEndian(payload[12..], transition);
        BinaryPrimitives.WriteSingleLittleEndian(payload[16..], timeToApplySeconds);

        return Encode(payload);
    }

    public static string EncodeV2(ulong unixTimestamp,
        byte weatherType,
        byte upcomingWeatherType,
        ushort transition,
        float timeToApplySeconds,
        float temperatureAmbient,
        float temperatureRoad,
        float trackGrip,
        float humidity,
        float windDirectionDeg,
        float windSpeed,
        float pressure,
        float rainIntensity,
        float rainWetness,
        float rainWater)
    {
        Span<byte> payload = stackalloc byte[V2PayloadSize];

        BinaryPrimitives.WriteUInt16LittleEndian(payload, (ushort)CSPClientMessageType.ConditionsV2);
        BinaryPrimitives.WriteUInt64LittleEndian(payload[2..], unixTimestamp);
        payload[10] = weatherType;
        payload[11] = upcomingWeatherType;
        BinaryPrimitives.WriteUInt16LittleEndian(payload[12..], transition);
        WriteHalf(payload[14..], timeToApplySeconds);
        WriteHalf(payload[16..], temperatureAmbient);
        WriteHalf(payload[18..], temperatureRoad);
        payload[20] = EncodeTrackGrip(trackGrip);
        payload[21] = EncodeByte(humidity);
        WriteHalf(payload[22..], windDirectionDeg);
        WriteHalf(payload[24..], windSpeed);
        WriteHalf(payload[26..], pressure);
        WriteHalf(payload[28..], rainIntensity);
        WriteHalf(payload[30..], rainWetness);
        WriteHalf(payload[32..], rainWater);

        return Encode(payload);
    }

    /// <summary>
    /// CSP stores track grip as a byte in the range 0.6 - 1.0, where 0.6 maps to 0 and 1.0 maps to 255.
    /// </summary>
    /// <remarks>
    /// Computed in double precision to match the reference implementation and to avoid float rounding
    /// pushing midpoints one step down.
    /// </remarks>
    public static byte EncodeTrackGrip(float trackGrip)
    {
        var normalized = Math.Clamp(((double)trackGrip - 0.6d) / 0.4d, 0d, 1d);
        return (byte)Math.Clamp(Math.Round(normalized * 255d), 0d, 255d);
    }

    /// <summary>
    /// CSP stores humidity as a byte in the range 0 - 100 -> 0 - 255, with 0 - 1 input.
    /// </summary>
    public static byte EncodeByte(float value) =>
        (byte)Math.Clamp(Math.Round(Math.Clamp((double)value, 0d, 1d) * 255d), 0d, 255d);

    /// <summary>
    /// Maps a <see cref="WeatherFxType"/> to the byte CSP expects.
    /// </summary>
    /// <remarks>
    /// The reference implementation writes <c>type - 1</c> because its own enum is 1 based.
    /// <see cref="WeatherFxType"/> is already 0 based, so the value is used as-is.
    /// <see cref="WeatherFxType.None"/> is not a valid CSP weather and maps to Clear.
    /// </remarks>
    public static byte EncodeWeatherType(WeatherFxType weatherFxType) =>
        weatherFxType == WeatherFxType.None
            ? (byte)WeatherFxType.Clear
            : (byte)weatherFxType;

    private static void WriteHalf(Span<byte> destination, float value) =>
        BinaryPrimitives.WriteUInt16LittleEndian(destination, BitConverter.HalfToUInt16Bits((Half)value));

    private static string Encode(ReadOnlySpan<byte> payload) =>
        $"{ChatPrefix}{Convert.ToBase64String(payload).TrimEnd('=')}";
}

/// <summary>
/// A chat encoded CSP conditions packet, already serialized and encoded.
/// </summary>
public readonly struct CSPWeatherConditions(string encoded) : IOutgoingNetworkPacket
{
    public string Encoded { get; } = encoded;

    public readonly void ToWriter(ref PacketWriter writer)
    {
        writer.Write((byte)ACServerProtocol.Chat);
        writer.Write(CSPConditionsWeather.SenderId);
        writer.WriteUTF32String(Encoded);
    }

    public readonly override string ToString() => Encoded;
}
