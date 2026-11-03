using System.Buffers.Binary;
using AssettoServer.Shared.Network.Packets.Outgoing;
using AssettoServer.Shared.Weather;
// ReSharper disable InconsistentNaming

namespace AssettoServer.Tests;

/// <summary>
/// Verifies the conditions payload against the reference wire format used by CSP:
/// https://github.com/rockavoldy/acserver-plugin-dynamic-condition/blob/main/internal/csp/csp.go
/// </summary>
public class CSPWeatherConditionsTests
{
    private const string Prefix = "\t\t\t\t$CSP0:";

    private static byte[] Decode(string encoded)
    {
        Assert.That(encoded, Does.StartWith(Prefix));

        var base64 = encoded[Prefix.Length..];
        var padding = (4 - base64.Length % 4) % 4;
        return Convert.FromBase64String(base64 + new string('=', padding));
    }

    [Test]
    public void V1_HasExpectedLayout()
    {
        var encoded = CSPConditionsWeather.EncodeV1(1_700_000_000, 19, 8, 0.5f, 1f);
        var payload = Decode(encoded);

        Assert.Multiple(() =>
        {
            Assert.That(payload, Has.Length.EqualTo(20));
            Assert.That(BinaryPrimitives.ReadUInt16LittleEndian(payload), Is.EqualTo(1000));
            Assert.That(BinaryPrimitives.ReadUInt64LittleEndian(payload.AsSpan(2)), Is.EqualTo(1_700_000_000));
            Assert.That(payload[10], Is.EqualTo(19));
            Assert.That(payload[11], Is.EqualTo(8));
            Assert.That(BinaryPrimitives.ReadSingleLittleEndian(payload.AsSpan(12)), Is.EqualTo(0.5f));
            Assert.That(BinaryPrimitives.ReadSingleLittleEndian(payload.AsSpan(16)), Is.EqualTo(1f));
        });
    }

    [Test]
    public void V2_HasExpectedLayout()
    {
        var encoded = CSPConditionsWeather.EncodeV2(1_700_000_000,
            weatherType: 19,
            upcomingWeatherType: 8,
            transition: 32768,
            timeToApplySeconds: 1f,
            temperatureAmbient: 24.5f,
            temperatureRoad: 31f,
            trackGrip: 0.8f,
            humidity: 0.6f,
            windDirectionDeg: 270f,
            windSpeed: 12f,
            pressure: 1013f,
            rainIntensity: 0.4f,
            rainWetness: 0.25f,
            rainWater: 0.1f);

        var payload = Decode(encoded);

        Assert.Multiple(() =>
        {
            Assert.That(payload, Has.Length.EqualTo(34));
            Assert.That(BinaryPrimitives.ReadUInt16LittleEndian(payload), Is.EqualTo(1001));
            Assert.That(BinaryPrimitives.ReadUInt64LittleEndian(payload.AsSpan(2)), Is.EqualTo(1_700_000_000));
            Assert.That(payload[10], Is.EqualTo(19));
            Assert.That(payload[11], Is.EqualTo(8));
            Assert.That(BinaryPrimitives.ReadUInt16LittleEndian(payload.AsSpan(12)), Is.EqualTo(32768));

            Assert.That(ReadHalf(payload, 14), Is.EqualTo(1f));
            Assert.That(ReadHalf(payload, 16), Is.EqualTo(24.5f));
            Assert.That(ReadHalf(payload, 18), Is.EqualTo(31f));

            // grip 0.8 -> (0.8 - 0.6) / 0.4 * 255 = 127.5 -> 128
            Assert.That(payload[20], Is.EqualTo(128));
            // humidity 0.6 * 255 = 153
            Assert.That(payload[21], Is.EqualTo(153));

            Assert.That(ReadHalf(payload, 22), Is.EqualTo(270f).Within(0.01f));
            Assert.That(ReadHalf(payload, 24), Is.EqualTo(12f).Within(0.01f));
            Assert.That(ReadHalf(payload, 26), Is.EqualTo(1013f).Within(1f));
            Assert.That(ReadHalf(payload, 28), Is.EqualTo(0.4f).Within(0.001f));
            Assert.That(ReadHalf(payload, 30), Is.EqualTo(0.25f).Within(0.001f));
            Assert.That(ReadHalf(payload, 32), Is.EqualTo(0.1f).Within(0.001f));
        });
    }

    [Test]
    public void EnvelopeMatchesChatEncoding()
    {
        // CSP requires trailing '=' padding to be trimmed, same as CSPClientMessageOutgoing
        var encoded = CSPConditionsWeather.EncodeV2(1_700_000_000, 19, 8, 0, 1f, 20f, 20f, 0.98f, 0.5f, 0f, 0f, 1000f, 0f, 0f, 0f);
        var base64 = encoded[Prefix.Length..];

        Assert.That(base64, Does.Not.EndWith("="));
        Assert.That(encoded.Length, Is.LessThan(80));
    }

    [Test]
    public void TrackGripIsClampedAndScaled()
    {
        Assert.Multiple(() =>
        {
            Assert.That(CSPConditionsWeather.EncodeTrackGrip(0.6f), Is.EqualTo(0));
            Assert.That(CSPConditionsWeather.EncodeTrackGrip(1f), Is.EqualTo(255));
            Assert.That(CSPConditionsWeather.EncodeTrackGrip(0.4f), Is.EqualTo(0));
            Assert.That(CSPConditionsWeather.EncodeTrackGrip(1.4f), Is.EqualTo(255));
        });
    }

    [Test]
    public void WeatherTypeUsesZeroBasedEnumWithoutOffset()
    {
        // The Go reference subtracts 1 because its enum is 1-based; ours is already 0-based.
        Assert.Multiple(() =>
        {
            Assert.That(CSPConditionsWeather.EncodeWeatherType(WeatherFxType.LightThunderstorm), Is.EqualTo(0));
            Assert.That(CSPConditionsWeather.EncodeWeatherType(WeatherFxType.Clear), Is.EqualTo(15));
            Assert.That(CSPConditionsWeather.EncodeWeatherType(WeatherFxType.OvercastClouds), Is.EqualTo(19));
            Assert.That(CSPConditionsWeather.EncodeWeatherType(WeatherFxType.Hail), Is.EqualTo(32));
        });
    }

    [Test]
    public void NoneWeatherTypeFallsBackToClear()
    {
        Assert.That(CSPConditionsWeather.EncodeWeatherType(WeatherFxType.None), Is.EqualTo((byte)WeatherFxType.Clear));
    }

    private static float ReadHalf(byte[] payload, int offset) =>
        (float)BitConverter.UInt16BitsToHalf(BinaryPrimitives.ReadUInt16LittleEndian(payload.AsSpan(offset)));
}
