using TougePlugin.Models;
using TougePlugin.Packets;

namespace TougePlugin.RaceTypes;

public class CourseRace : IRaceType
{
    public async Task<RaceResult> RunRaceAsync(Race race)
    {
        bool leaderSubscribed = false;
        bool followerSubscribed = false;

        try
        {
            if (race.Configuration.UseTrackFinish)
            {
                if (race.Leader.Client is { } leaderClient)
                {
                    leaderClient.LapCompleted += race.OnClientLapCompleted;
                    leaderSubscribed = true;
                }

                if (race.Follower.Client is { } followerClient)
                {
                    followerClient.LapCompleted += race.OnClientLapCompleted;
                    followerSubscribed = true;
                }
            }
            else
            {
                NotifyLookForFinish(true, race);
            }

            Task completedRace = await Task.WhenAny(race.SecondLapCompleted.Task, race.Disconnected.Task, race.FollowerFirst.Task);

            if (completedRace == race.Disconnected.Task)
            {
                race.SendMessage("Race cancelled due to disconnection or forfeit.");
                return RaceResult.Disconnected(race.Disconnected.Task.Result.EntryCar);
            }
            else if (!race.FollowerSetLap)
            {
                race.SendMessage($"{race.FollowerName} did not finish in time. {race.LeaderName} wins!");
                return RaceResult.Win(race.Leader);
            }
            else if (completedRace == race.FollowerFirst.Task)
            {
                race.SendMessage($"{race.FollowerName} overtook {race.LeaderName}. {race.FollowerName} wins!");
                return RaceResult.Win(race.Follower);
            }
            else
            {
                race.SendMessage($"{race.LeaderName} did not pull away. It's a tie!");
                return RaceResult.Tie();
            }
        }
        finally
        {
            NotifyLookForFinish(false, race);

            if (leaderSubscribed && race.Leader.Client is { } leaderClient)
                leaderClient.LapCompleted -= race.OnClientLapCompleted;
            if (followerSubscribed && race.Follower.Client is { } followerClient)
                followerClient.LapCompleted -= race.OnClientLapCompleted;
        }
    }

    private static void NotifyLookForFinish(bool lookForFinish, Race race)
    {
        if (race.Leader.Client is { } leaderClient)
        {
            leaderClient.SendPacket(new FinishPacket
            {
                LookForFinish = lookForFinish,
            });
        }

        if (race.Follower.Client is { } followerClient)
        {
            followerClient.SendPacket(new FinishPacket
            {
                LookForFinish = lookForFinish,
            });
        }
    }


}
