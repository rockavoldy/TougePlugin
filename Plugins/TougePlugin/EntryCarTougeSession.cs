using System.Numerics;
using AssettoServer.Network.Tcp;
using AssettoServer.Server;
using Serilog;
using TougePlugin.Models;
using TougePlugin.Packets;
using TougePlugin.TougeRulesets;

namespace TougePlugin;

// Instance attached to each EntryCar that manages TougeSessions
// Handles sending and accepting invites and starting the TougeSession
public class EntryCarTougeSession
{
    private readonly EntryCarManager _entryCarManager;
    private readonly Touge _plugin;
    private readonly EntryCar _entryCar;
    private readonly TougeSession.Factory _tougeSessionFactory;
    private readonly Func<RulesetType, ITougeRuleset> _rulesetFactory;
    private readonly TougeConfiguration _configuration;

    // Serializes session attach/detach across both participants of an invite.
    private static readonly object SessionStateLock = new();

    internal TougeSession? CurrentSession { get; set; }

    public EntryCarTougeSession(EntryCar entryCar, EntryCarManager entryCarManager, Touge plugin, TougeSession.Factory tougeSessionFactory, Func<RulesetType, ITougeRuleset> rulesetFactory, TougeConfiguration configuration)
    {
        _entryCar = entryCar;
        _entryCarManager = entryCarManager;
        _plugin = plugin;
        _tougeSessionFactory = tougeSessionFactory;
        _rulesetFactory = rulesetFactory;
        _entryCar.ResetInvoked += OnResetInvoked;
        _configuration = configuration;
    }

    private void OnResetInvoked(EntryCar sender, EventArgs args)
    {
        TougeSession? session;
        lock (SessionStateLock)
        {
            session = CurrentSession;
            CurrentSession = null;
        }

        if (session == null)
            return;

        EntryCar opponent = ReferenceEquals(sender, session.Challenger) ? session.Challenged : session.Challenger;
        _plugin.GetSession(opponent).ClearSessionIfCurrent(session);
    }

    internal void ClearSessionIfCurrent(TougeSession session)
    {
        lock (SessionStateLock)
        {
            if (ReferenceEquals(CurrentSession, session))
                CurrentSession = null;
        }
    }

    internal EntryCar? FindNearbyCar()
    {
        EntryCar? bestMatch = null;
        const float distanceSquared = 30 * 30;
        float closestDistanceSquared = float.MaxValue; // Start with the largest possible distance

        foreach (EntryCar car in _entryCarManager.EntryCars)
        {
            ACTcpClient? carClient = car.Client;
            if (carClient != null && car != _entryCar)
            {
                // Calculate the squared distance between the two cars
                float distanceToCarSquared = Vector3.DistanceSquared(car.Status.Position, _entryCar.Status.Position);

                // Only consider the car if it's within the range
                if (distanceToCarSquared < distanceSquared)
                {
                    // If this car is closer than the previous best match, update bestMatch
                    if (distanceToCarSquared < closestDistanceSquared)
                    {
                        closestDistanceSquared = distanceToCarSquared;
                        bestMatch = car;
                    }
                }
            }
        }
        return bestMatch;
    }

    internal List<EntryCar> FindClosestCars(int count)
    {
        var closestCars = _entryCarManager.EntryCars
            .Where(car => car.Client != null && car != _entryCar)
            .Select(car => new
            {
                Car = car,
                DistanceSquared = Vector3.DistanceSquared(car.Status.Position, _entryCar.Status.Position)
            })
            .OrderBy(x => x.DistanceSquared)
            .Take(count)
            .Select(x => x.Car)
            .ToList();

        return closestCars;
    }

    // Challenges car to a touge session.
    // Updates CurrentSession for both cars if invite is succesfully sent.
    // If session isn't active after 10 seconds, it withdraws the invite.
    // In this case it sets the CurrentSession back to null for both cars.
    internal async Task ChallengeCar(EntryCar car, string courseName, bool isCourse = true)
    {
        Log.Debug("[TougeSession] ChallengeCar from {ChallengerName} ({ChallengerSessionId}) to {TargetName} ({TargetSessionId}) course={CourseName} isCourse={IsCourse}",
            _entryCar.Client?.Name, _entryCar.SessionId, car.Client?.Name, car.SessionId, courseName, isCourse);

        void Reply(string message)
        {
            Touge.SendNotification(_entryCar.Client, message);
        }

        if (!_plugin.tougeCourses.TryGetValue(courseName, out Course course))
        {
            Reply("Course not found.");
            return;
        }

        var ruleset = _rulesetFactory(_configuration.RuleSetType);
        RaceType raceType = isCourse ? RaceType.Course : RaceType.Outrun;

        TougeSession? session = null;
        string? rejectMessage = null;

        lock (SessionStateLock)
        {
            if (CurrentSession != null)
            {
                rejectMessage = CurrentSession.IsActive
                    ? "You are already in an active touge session."
                    : "You have a pending session invite.";
            }
            else if (car == _entryCar)
            {
                rejectMessage = "You cannot invite yourself to a session.";
            }
            else
            {
                var targetSession = _plugin.GetSession(car).CurrentSession;
                if (targetSession != null)
                {
                    rejectMessage = targetSession.IsActive
                        ? "This car is already in a touge session."
                        : "This car has a pending touge session invite.";
                }
                else
                {
                    // Create a new TougeSession instance and attach it to both cars.
                    session = _tougeSessionFactory(_entryCar, car, ruleset, course, raceType);
                    CurrentSession = session;
                    _plugin.GetSession(car).CurrentSession = session;
                }
            }
        }

        if (rejectMessage != null)
        {
            Reply(rejectMessage);
            return;
        }

        // Get sender's elo
        var (senderElo, _) = await _plugin.database.GetPlayerStatsAsync(_entryCar.Client!.Guid!.ToString());

        car.Client?.SendPacket(new InvitePacket { InviteSenderName = _entryCar.Client!.Name!, InviteSenderElo = senderElo, InviteSenderId = _entryCar.Client!.Guid.ToString(), CourseName = courseName });

        _ = Task.Delay(10000).ContinueWith(_ =>
        {
            lock (SessionStateLock)
            {
                if (!session!.IsActive && ReferenceEquals(CurrentSession, session))
                {
                    CurrentSession = null;
                    _plugin.GetSession(car).ClearSessionIfCurrent(session!);

                    Touge.SendNotification(_entryCar.Client, "Invite was not accepted in time.");
                }
            }
        });
    }


}
