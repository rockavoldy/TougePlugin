using AssettoServer.Network.ClientMessages;

namespace TougePlugin.Packets;

[OnlineEvent(Key = "AS_SessionState")]
public class SessionStatePacket : OnlineEvent<SessionStatePacket>
{
    [OnlineEventField(Name = "result1")]
    public int Result1;
    [OnlineEventField(Name = "result2")]
    public int Result2;
    [OnlineEventField(Name = "result3")]
    public int Result3;
    [OnlineEventField(Name = "sessionState")]
    public int SessionState;
    // Session id of the opponent's car, or -1 when there is no active session. The client
    // reads the opponent's name, car and track position from that car.
    [OnlineEventField(Name = "rivalSessionId")]
    public int RivalSessionId = -1;
}
