using System.Numerics;
using AssettoServer.Network.Tcp;
using AssettoServer.Server;
using TougePlugin.RaceTypes;
using Serilog;
using TougePlugin.Models;
using TougePlugin.Packets;

namespace TougePlugin;

public class Race
{
    public EntryCar Leader { get; }
    public EntryCar Follower { get; }

    private readonly EntryCarManager _entryCarManager;
    public readonly TougeConfiguration Configuration;
    private readonly Touge _plugin;
    public readonly SessionManager SessionManager;

    public enum JumpstartResult
    {
        None,            // No jumpstart
        Leader,          // Leader performed a jumpstart
        Follower,        // Follower performed a jumpstart
        Both             // Both performed a jumpstart (if both are outside the threshold)
    }

    private bool LeaderSetLap = false;
    public bool FollowerSetLap = false;
    
    public readonly TaskCompletionSource<ACTcpClient> Forfeit = new();
    public TaskCompletionSource<bool> SecondLapCompleted { get; } = new();
    public TaskCompletionSource<ACTcpClient> Disconnected { get; } = new();
    public TaskCompletionSource<bool> FollowerFirst { get; } = new();

    public string LeaderName { get; }
    public string FollowerName { get; }

    private bool IsGo = false;
    private volatile bool _cancelled;

    private readonly IRaceType _raceType;
    private readonly Course _course;

    private static int _raceIdCounter;
    private readonly int _raceId = System.Threading.Interlocked.Increment(ref _raceIdCounter);

    private const int LivenessPollIntervalMs = 250;
    private const int MaxLivenessMisses = 3;
    private const int UnresponsivePongThresholdMs = 4000;

    public delegate Race Factory(EntryCar leader, EntryCar follower, IRaceType raceType, Course course);

    public Race(EntryCar leader, EntryCar follower, IRaceType raceType, EntryCarManager entryCarManager, TougeConfiguration configuration, Touge plugin, SessionManager sessionManager, Course course)
    {
        Leader = leader;
        Follower = follower;

        LeaderName = Leader.Client?.Name!;
        FollowerName = Follower.Client?.Name!;

        _entryCarManager = entryCarManager;
        Configuration = configuration;
        _plugin = plugin;
        SessionManager = sessionManager;
        _raceType = raceType;

        if (Leader.Client is { } leaderClient)
            leaderClient.Disconnecting += OnClientDisconnected;
        if (Follower.Client is { } followerClient)
            followerClient.Disconnecting += OnClientDisconnected;
        _course = course;

        Log.Debug("[TougeRace {RaceId}] Race created. Leader={LeaderName} ({LeaderSessionId}) Follower={FollowerName} ({FollowerSessionId})",
            _raceId, LeaderName, Leader.SessionId, FollowerName, Follower.SessionId);
    }

    public async Task<RaceResult> RaceAsync()
    {
        using var livenessCts = new CancellationTokenSource();
        Task livenessTask = MonitorParticipantsAsync(livenessCts.Token);

        try
        {
            Log.Debug("[TougeRace {RaceId}] RaceAsync started", _raceId);

            SpawnPair? startSlots = await InitializeRaceAsync();
            if (startSlots == null)
            {
                return RaceResult.Disconnected(null);
            }

            SendMessage("Race starting soon...");
            if (await WaitWithForfeitAsync(Task.Delay(3000)))
                return RaceResult.Disconnected(Forfeit.Task.Result.EntryCar);

            var countdownResult = await RunCountdownAsync(startSlots);
            if (countdownResult != null)
            {
                return countdownResult;
            }

            return await _raceType.RunRaceAsync(this);
        }

        catch (Exception e)
        {
            Log.Error(e, "[TougeRace {RaceId}] Error while running race", _raceId);
            SendMessage("There was an error while runnning the race.");
            return RaceResult.Error();
        }
        finally
        {
            livenessCts.Cancel();
            try
            {
                await livenessTask;
            }
            catch (Exception ex)
            {
                Log.Debug(ex, "[TougeRace {RaceId}] Liveness monitor stopped with error", _raceId);
            }
            FinishRace();
        }
    }

    private async Task<SpawnPair?> InitializeRaceAsync()
    {
        Log.Debug("[TougeRace {RaceId}] InitializeRaceAsync started", _raceId);

        var setupTask = Task.Run(() => SetUpRaceAsync());
        _ = setupTask.ContinueWith(t =>
        {
            if (t.IsFaulted)
                Log.Error(t.Exception, "[TougeRace {RaceId}] SetUpRaceAsync background task faulted", _raceId);
        }, TaskContinuationOptions.ExecuteSynchronously);

        var forfeitTask = Forfeit.Task;

        var completedSetup = await Task.WhenAny(setupTask, forfeitTask);

        if (completedSetup == forfeitTask)
        {
            _cancelled = true;
            Log.Debug("[TougeRace {RaceId}] Setup cancelled by forfeit. Awaiting background setup before cleanup", _raceId);

            // Continue observing the setup task so an in-flight teleport loop can
            // exit via _cancelled instead of continuing after the player forfeited.
            try
            {
                await setupTask;
            }
            catch (OperationCanceledException)
            {
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "[TougeRace {RaceId}] Background setup failed after forfeit cancellation", _raceId);
            }

            SendMessage("Race cancelled due to player forfeit.");
            return null;
        }

        SpawnPair? startSlots = await setupTask;

        if (startSlots == null)
        {
            Log.Debug("[TougeRace {RaceId}] Setup failed or teleport timed out", _raceId);
            SendMessage("Teleportation failed. Race setup aborted.");
            return null;
        }

        Log.Debug("[TougeRace {RaceId}] InitializeRaceAsync completed", _raceId);
        return startSlots;
    }

    private async Task<RaceResult?> RunCountdownAsync(SpawnPair startSlots)
    {
        Log.Debug("[TougeRace {RaceId}] RunCountdownAsync started (IsRollingStart={IsRollingStart})", _raceId, Configuration.IsRollingStart);

        while (!IsGo)
        {
            byte signalStage = 0;
            // Short beeps at 0s, 1s, 2s and 3s; the long Go beep starts at 4.15s.
            while (signalStage < 5)
            {
                if (!Configuration.IsRollingStart)
                {
                    JumpstartResult jumpstart = AreInStartingPos(startSlots);
                    if (jumpstart != JumpstartResult.None)
                    {
                        if (jumpstart == JumpstartResult.Both)
                        {
                            SendMessage("Both players made a jumpstart.");
                            await RestartRaceAsync();
                            break;
                        }
                        else if (jumpstart == JumpstartResult.Follower)
                        {
                            SendMessage($"{FollowerName} made a jumpstart. {LeaderName} wins this race.");
                            return RaceResult.Win(Leader);
                        }
                        else
                        {
                            SendMessage($"{LeaderName} made a jumpstart. {FollowerName} wins this race.");
                            return RaceResult.Win(Follower);
                        }
                    }
                }

                if (signalStage == 0)
                    _ = SendTimedMessageAsync("Ready...", true);
                else if (signalStage == 1)
                    _ = SendTimedMessageAsync("Set...", true);
                else if (signalStage == 4)
                {
                    if (Configuration.IsRollingStart)
                    {
                        // Check if cars are close enough to each other to give a valid "Go!".
                        if (!IsValidRollingStartPos())
                        {
                            SendMessage("Players are not close enough for a fair rolling start.");
                            await RestartRaceAsync();
                            break;
                        }
                    }
                    _ = SendTimedMessageAsync("Go!", true);
                    Log.Information("[TougeRace {RaceId}] Countdown reached Go", _raceId);
                    IsGo = true;
                    break;
                }
                if (await WaitWithForfeitAsync(Task.Delay(signalStage == 3 ? 1150 : 1000)))
                    return RaceResult.Disconnected(Forfeit.Task.Result.EntryCar);
                signalStage++;
            }
        }

        return null;
    }

    private void FinishRace()
    {
        Log.Debug("[TougeRace {RaceId}] FinishRace cleanup", _raceId);

        // General clean up
        if (Leader.Client is { } leaderClient) leaderClient.Disconnecting -= OnClientDisconnected;
        if (Follower.Client is { } followerClient) followerClient.Disconnecting -= OnClientDisconnected;
    }

    public void SendMessage(string message)
    {
        Touge.SendNotification(Follower.Client, message);
        Touge.SendNotification(Leader.Client, message);
    }

    private async Task RestartRaceAsync()
    {
        SendMessage("Returning both players to their starting positions.");
        SendMessage("Race restarting soon...");
        await Task.Delay(3000);
        SpawnPair startSlots = await GetStartSlotsAsync();
        await TeleportToStartAsync(Leader, Follower, startSlots);
    }

    public void OnClientLapCompleted(ACTcpClient sender, LapCompletedEventArgs? args)
    {
        var car = sender.EntryCar;
        if (car == Leader)
            LeaderSetLap = true;
        else if (car == Follower)
            FollowerSetLap = true;

        // If someone already set a lap, and this is the seconds person to set a lap
        if (LeaderSetLap && FollowerSetLap)
            SecondLapCompleted.TrySetResult(true);

        // If only the leader has set a lap
        else if (LeaderSetLap && !FollowerSetLap)
        {
            // Make this time also configurable as outrun time.
            int outrunTimer = (int)(Configuration.CourseOutrunTime * 1000f);
            _ = Task.Delay(outrunTimer).ContinueWith(_ => SecondLapCompleted.TrySetResult(false));
        }

        // Overtake, the follower finished earlier than leader.
        else if (FollowerSetLap && !LeaderSetLap)
            FollowerFirst.TrySetResult(true);
    }

    private void OnClientDisconnected(ACTcpClient sender, EventArgs args)
    {
        Log.Debug("[TougeRace {RaceId}] Client disconnecting: {ClientName} ({SessionId})", _raceId, sender.Name, sender.SessionId);
        ForfeitPlayer(sender);
    }

    internal void ForfeitPlayer(ACTcpClient sender)
    {
        Log.Debug("[TougeRace {RaceId}] Forfeit/disconnect requested by {ClientName} ({SessionId}), IsGo={IsGo}, RaceType={RaceTypeName}",
            _raceId, sender.Name, sender.SessionId, IsGo, _raceType.GetType().Name);

        _cancelled = true;

        // Signal both completion sources so whichever stage of the race is
        // currently waiting wakes up deterministically. Setup/countdown wait on
        // Forfeit, while an in-progress course race waits on Disconnected.
        // Routing the signal on a single non-volatile IsGo field could read a
        // stale value across threads and complete the wrong source, leaving the
        // race (and therefore the session) suspended forever.
        Forfeit.TrySetResult(sender);
        Disconnected.TrySetResult(sender);

        if (!Configuration.UseTrackFinish)
        {
            sender.SendPacket(new FinishPacket { LookForFinish = false });
        }
        UnlockControls();
    }

    private async Task MonitorParticipantsAsync(CancellationToken token)
    {
        int leaderMisses = 0;
        int followerMisses = 0;

        try
        {
            while (!token.IsCancellationRequested && !_cancelled)
            {
                await Task.Delay(LivenessPollIntervalMs, token);

                if (Leader.Client is { } leaderClient && IsUnresponsive(Leader))
                {
                    if (++leaderMisses >= MaxLivenessMisses)
                    {
                        Log.Warning("[TougeRace {RaceId}] {ClientName} stopped responding and will be forfeited", _raceId, leaderClient.Name);
                        ForfeitPlayer(leaderClient);
                        return;
                    }
                }
                else
                {
                    leaderMisses = 0;
                }

                if (Follower.Client is { } followerClient && IsUnresponsive(Follower))
                {
                    if (++followerMisses >= MaxLivenessMisses)
                    {
                        Log.Warning("[TougeRace {RaceId}] {ClientName} stopped responding and will be forfeited", _raceId, followerClient.Name);
                        ForfeitPlayer(followerClient);
                        return;
                    }
                }
                else
                {
                    followerMisses = 0;
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Race finished normally; the monitor has been stopped.
        }
    }

    private bool IsUnresponsive(EntryCar car)
    {
        return car.LastPongTime > 0
            && SessionManager.ServerTimeMilliseconds - car.LastPongTime > UnresponsivePongThresholdMs;
    }

    private async Task<bool> TeleportToStartAsync(EntryCar Leader, EntryCar Follower, SpawnPair startSlots)
    {
        Log.Debug("[TougeRace {RaceId}] TeleportToStartAsync leader={LeaderSessionId} follower={FollowerSessionId}",
            _raceId, Leader.SessionId, Follower.SessionId);

        if (Leader.Client is not { } leaderClient || Follower.Client is not { } followerClient)
        {
            Log.Warning("[TougeRace {RaceId}] TeleportToStartAsync cannot proceed because a client is unavailable. LeaderConnected={LeaderConnected} FollowerConnected={FollowerConnected}",
                _raceId, Leader.Client != null, Follower.Client != null);
            return false;
        }

        leaderClient.SendPacket(new TeleportPacket
        {
            Position = startSlots.Leader.Position,
            Heading = startSlots.Leader.Heading,
        });
        followerClient.SendPacket(new TeleportPacket
        {
            Position = startSlots.Follower.Position,
            Heading = startSlots.Follower.Heading,
        });

        // Check if both cars have been teleported to their starting locations.
        bool isLeaderTeleported = false;
        bool isFollowerTeleported = false;
        const float thresholdSquared = 50f;

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var token = cts.Token;

        try
        {
            while (!isLeaderTeleported || !isFollowerTeleported)
            {
                if (_cancelled)
                {
                    Log.Debug("[TougeRace {RaceId}] Teleport aborted because race was cancelled", _raceId);
                    return false;
                }

                Vector3 currentLeaderPos = Leader.Status.Position;
                Vector3 currentFollowerPos = Follower.Status.Position;

                float leaderDistanceSquared = Vector3.DistanceSquared(currentLeaderPos, startSlots.Leader.Position);
                float followerDistanceSquared = Vector3.DistanceSquared(currentFollowerPos, startSlots.Follower.Position);

                if (leaderDistanceSquared < thresholdSquared)
                {
                    isLeaderTeleported = true;
                }
                if (followerDistanceSquared < thresholdSquared)
                {
                    isFollowerTeleported = true;
                }

                await Task.Delay(250, token);
            }

            return true;
        }
        catch (OperationCanceledException)
        {
            Log.Warning("[TougeRace {RaceId}] TeleportToStartAsync timed out. leaderTeleported={LeaderTeleported} followerTeleported={FollowerTeleported}",
                _raceId, isLeaderTeleported, isFollowerTeleported);
            return false;
        }
        finally
        {
            UnlockControls();
        }
    }

    private async Task SendTimedMessageAsync(string message, bool isCountdown = false)
    {
        bool isChallengerHighPing = Leader.Ping > Follower.Ping;
        EntryCar highPingCar, lowPingCar;

        if (isChallengerHighPing)
        {
            highPingCar = Leader;
            lowPingCar = Follower;
        }
        else
        {
            highPingCar = Follower;
            lowPingCar = Leader;
        }

        Touge.SendNotification(highPingCar.Client, message, isCountdown);
        await Task.Delay(highPingCar.Ping - lowPingCar.Ping);
        Touge.SendNotification(lowPingCar.Client, message, isCountdown);
    }

    // Check if the cars are still in their starting positions.
    private JumpstartResult AreInStartingPos(SpawnPair startSlots)
    {
        // Get the current position of each car.
        Vector3 currentLeaderPos = Leader.Status.Position;
        Vector3 currentFollowerPos = Follower.Status.Position;

        // Check if they are the same as the original starting postion.
        // Or at least check if the difference is not larger than a threshold.
        float leaderDistanceSquared = Vector3.DistanceSquared(currentLeaderPos, startSlots.Leader.Position);
        float followerDistanceSquared = Vector3.DistanceSquared(currentFollowerPos, startSlots.Follower.Position);

        const float thresholdSquared = 20f;

        // Check if either car has moved too far (jumpstart detection)
        if (leaderDistanceSquared > thresholdSquared && followerDistanceSquared > thresholdSquared)
        {
            // Both cars moved too far
            return JumpstartResult.Both;
        }
        else if (leaderDistanceSquared > thresholdSquared)
        {
            return JumpstartResult.Leader; // Leader caused the jumpstart
        }
        else if (followerDistanceSquared > thresholdSquared)
        {
            return JumpstartResult.Follower; // Follower caused the jumpstart
        }

        return JumpstartResult.None; // No jumpstart
    }

    private bool IsValidRollingStartPos()
    {
        // Check if players are within a certain distance of each other.
        float distanceBetweenCars = Vector3.DistanceSquared(Follower.Status.Position, Leader.Status.Position);
        if (distanceBetweenCars > 30)
            return false;
        return true;
    }

    private SpawnPair? FindClearStartArea()
    {
        // Loop over the list of starting positions in the cfg file
        // If you find a valid/clear starting pos, return that.
        foreach (var spawnPair in _course.StartingSlots)
        {
            if (IsStartPosClear(spawnPair.Leader.Position) && IsStartPosClear(spawnPair.Follower.Position))
            {
                return spawnPair;
            }
        }
        return null;
    }

    private bool IsStartPosClear(Vector3 startPos)
    {
        // Checks if startPos is clear.
        const float startArea = 50f; // Area around the startpoint that should be cleared.
        foreach (var car in _entryCarManager.EntryCars)
        {
            // Dont look at the players in the race or empty cars
            ACTcpClient? carClient = car.Client;
            if (carClient != null && car != Leader && car != Follower)
            {
                // Check if they are not in the starting area.
                float distanceToStartPosSquared = Vector3.DistanceSquared(car.Status.Position, startPos);
                if (distanceToStartPosSquared < startArea)
                {
                    // The car is in the start area.
                    return false;
                }
            }
        }
        return true;
    }

    private async Task<SpawnPair> GetStartSlotsAsync()
    {
        // Get the startingArea here.
        int waitTime = 0;
        SpawnPair? startingArea = FindClearStartArea();
        while (startingArea == null)
        {
            // Wait for a short time before checking again to avoid blocking the thread
            await Task.Delay(250);

            // Try to find a starting area again
            startingArea = FindClearStartArea();

            waitTime += 1;
            if (waitTime > 40)
            {
                // Fallback after 10 seconds.
                startingArea = _course.StartingSlots[0];
            }
        }
        return startingArea;
    }

    private void SendFinishLine(Course course)
    {
        if (course.FinishLine == null)
        {
            Log.Warning("[TougeRace {RaceId}] Skipping SendFinishLine because FinishLine is not defined", _raceId);
            return;
        }

        if (Leader.Client is { } leaderClient)
            leaderClient.SendPacket(new FinishLinePacket { FinishPoint1 = course.FinishLine[0], FinishPoint2 = course.FinishLine[1] });
        if (Follower.Client is { } followerClient)
            followerClient.SendPacket(new FinishLinePacket { FinishPoint1 = course.FinishLine[0], FinishPoint2 = course.FinishLine[1] });
    }

    private async Task<SpawnPair?> SetUpRaceAsync()
    {
        SpawnPair startSlots = await GetStartSlotsAsync();

        if (_cancelled)
        {
            Log.Debug("[TougeRace {RaceId}] SetUpRaceAsync aborted after start slots because race was cancelled", _raceId);
            return null;
        }

        if (!Configuration.UseTrackFinish)
        {
            SendFinishLine(_course);
        }

        // First teleport players to their starting positions.
        bool isTeleported = await TeleportToStartAsync(Leader, Follower, startSlots);

        if (!isTeleported)
        {
            SendMessage("Teleportation failed. Race setup timed out.");
            return null;
        }

        return startSlots;
    }
    private async Task<bool> WaitWithForfeitAsync(Task task)
    {
        var completed = await Task.WhenAny(task, Forfeit.Task);
        if (completed == Forfeit.Task)
        {
            SendMessage("Race cancelled due to player forfeit.");
            return true;
        }

        await task; // Propagate exceptions if needed
        return false;
    }

    private void UnlockControls()
    {
        if (Leader.Client is { } leaderClient)
            leaderClient.SendPacket(new LockControlsPacket { LockControls = false });
        if (Follower.Client is { } followerClient)
            followerClient.SendPacket(new LockControlsPacket { LockControls = false });
    }
}
