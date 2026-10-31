using AssettoServer.Commands;
using AssettoServer.Commands.Attributes;
using TougePlugin.Packets;
using Qmmands;

namespace TougePlugin;

public class TougeCommandModule : ACModuleBase
{
    private readonly Touge _plugin;

    public TougeCommandModule(Touge plugin)
    {
        _plugin = plugin;
    }

    [Command("invite"), RequireConnectedPlayer]
    public void Invite()
    {
        _plugin.InviteNearbyCar(Client!);  
    }

    [Command("accepttouge"), RequireConnectedPlayer]
    public async ValueTask AcceptInvite()
    {
        var currentSession = _plugin.GetSession(Client!.EntryCar).CurrentSession;
        if (currentSession == null)
            Reply("You do not have a pending touge session invite.");
        else if (currentSession.Challenger == Client!.EntryCar)
            Reply("You cannot accept an invite you sent.");
        else if (currentSession.IsActive)
            Reply("You are already in an active touge session.");
        else
        {
            Reply("Invite succesfully accepted!");
            // This currentSession object is shared among the two players.
            // They both hold a reference to it.
            await currentSession.StartAsync();
        }
    }

    [Command("elo"), RequireConnectedPlayer]
    public async Task ShowEloAsync()
    {
        // Get the players current elo
        var (elo, _) = await _plugin.database.GetPlayerStatsAsync(Client!.Guid.ToString());
        
        // Send elo packet
        Client!.SendPacket(new EloPacket { Elo = elo });
    }

    // Debug commands for testing the HUD without an opponent. They only send packets to the
    // caller and do not change any session.

    // state: 0 Off, 1 FirstTwo, 2 SuddenDeath, 3 Finished, 4 CatAndMouse, 5 NoUpdate.
    // results: up to three of W, L, T or - (to be decided), for example "WL-".
    // rivalSessionId defaults to the caller's own car.
    [Command("tougedebug_state"), RequireAdmin, RequireConnectedPlayer]
    public void DebugSessionState(int state, string results = "---", int rivalSessionId = -1)
    {
        int[] standings = [0, 0, 0];
        for (int i = 0; i < Math.Min(3, results.Length); i++)
        {
            standings[i] = char.ToUpperInvariant(results[i]) switch
            {
                'W' => 1,
                'L' => 2,
                'T' => 3,
                _ => 0,
            };
        }

        if (rivalSessionId < 0)
            rivalSessionId = Client!.SessionId;

        Client!.SendPacket(new SessionStatePacket
        {
            Result1 = standings[0],
            Result2 = standings[1],
            Result3 = standings[2],
            SessionState = state,
            RivalSessionId = state == 0 ? -1 : rivalSessionId,
        });
        Reply($"Sent session state {state}, results {results}, rival {rivalSessionId}.");
    }

    [Command("tougedebug_notify"), RequireAdmin, RequireConnectedPlayer]
    public void DebugNotification([Remainder] string message)
    {
        Touge.SendNotification(Client, message);
    }

    [Command("tougedebug_countdown"), RequireAdmin, RequireConnectedPlayer]
    public async Task DebugCountdownAsync()
    {
        foreach (string step in new[] { "Ready...", "Set...", "Go!" })
        {
            Touge.SendNotification(Client, step, true);
            await Task.Delay(1000);
        }
    }
}
