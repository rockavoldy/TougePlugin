using AssettoServer.Network.ClientMessages;

namespace TougePlugin.Packets;

[OnlineEvent(Key = "TP_RaceCollision")]
public class RaceCollisionPacket : OnlineEvent<RaceCollisionPacket>
{
    [OnlineEventField(Name = "targetSessionId")]
    public byte TargetSessionId;
    [OnlineEventField(Name = "enabled")]
    public bool Enabled;
}
