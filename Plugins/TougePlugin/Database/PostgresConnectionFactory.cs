using System.Data.Common;
using Npgsql;

namespace TougePlugin.Database;

public class PostgresConnectionFactory(string connectionString) : IDbConnectionFactory
{
    public DbConnection CreateConnection()
    {
        return new NpgsqlConnection(connectionString);
    }

    public Task InitializeDatabase()
    {
        // Assume DB exists. Make new table if its missing.
        using var connection = new NpgsqlConnection(connectionString);
        connection.Open();

        var command = connection.CreateCommand();
        command.CommandText = @"
            CREATE TABLE IF NOT EXISTS Players (
                PlayerId TEXT PRIMARY KEY,
                Rating INTEGER,
                RacesCompleted INTEGER
            );";
        command.ExecuteNonQuery();

        return Task.CompletedTask;
    }

    public void EnsurePlayerExists(DbConnection connection, string playerId)
    {
        using var command = connection.CreateCommand();
        command.CommandText = @"
            INSERT INTO Players (PlayerId, Rating, RacesCompleted)
            VALUES (@PlayerId, @Rating, @RacesCompleted)
            ON CONFLICT (PlayerId) DO NOTHING;
        ";
        command.AddParameter("@PlayerId", playerId);
        command.AddParameter("@Rating", 1000);
        command.AddParameter("@RacesCompleted", 0);
        command.ExecuteNonQuery();
    }
}
