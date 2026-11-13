using System.Data.Common;

namespace TougePlugin.Database;

public interface IDbConnectionFactory
{
    DbConnection CreateConnection();
    Task InitializeDatabase();
    void EnsurePlayerExists(DbConnection connection, string playerId);
}
