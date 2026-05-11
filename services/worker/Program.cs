using System;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        public static int Main(string[] args)
        {
            try
            {
                // Fetch configuration from environment variables
                var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "db";
                var dbUsername = Environment.GetEnvironmentVariable("DB_USERNAME") ?? "postgres";
                var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "postgres";
                var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "postgres";
                
                var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";

                Console.WriteLine("=== Worker Configuration ===");
                Console.WriteLine($"DB_HOST: {dbHost}");
                Console.WriteLine($"DB_USERNAME: {dbUsername}");
                Console.WriteLine($"DB_PASSWORD: {(string.IsNullOrEmpty(dbPassword) ? "<empty>" : $"<set, length={dbPassword.Length}>")}");
                Console.WriteLine($"DB_NAME: {dbName}");
                Console.WriteLine($"REDIS_HOST: {redisHost}");

                // Construct the connection strings
                // Use NpgsqlConnectionStringBuilder to properly handle special characters in password
                // AWS RDS requires SSL
                Console.WriteLine("Building PostgreSQL connection string...");
                var builder = new NpgsqlConnectionStringBuilder
                {
                    Host = dbHost,
                    Username = dbUsername,
                    Password = dbPassword,
                    Database = dbName,
                    SslMode = SslMode.Require,
                    TrustServerCertificate = true
                };
                var pgConnectionString = builder.ConnectionString;
                
                // Log connection string without password
                var safeBuilder = new NpgsqlConnectionStringBuilder(pgConnectionString) { Password = "<redacted>" };
                Console.WriteLine($"Connection string: {safeBuilder.ConnectionString}");
                Console.WriteLine($"SSL Mode: {builder.SslMode}");
                Console.WriteLine($"Trust Server Certificate: {builder.TrustServerCertificate}");
                Console.WriteLine("===========================");
                Console.WriteLine();
                var redisConnectionString = redisHost;

                var pgsql = OpenDbConnection(pgConnectionString);
                var redisConn = OpenRedisConnection(redisConnectionString);
                var redis = redisConn.GetDatabase();

                Console.WriteLine();
                Console.WriteLine("====================================");
                Console.WriteLine("   WORKER READY - Polling for votes");
                Console.WriteLine("====================================");
                Console.WriteLine();

                // Keep alive is not implemented in Npgsql yet. This workaround was recommended:
                // https://github.com/npgsql/npgsql/issues/1214#issuecomment-235828359
                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new { vote = "", voter_id = "" };
                while (true)
                {
                    // Slow down to prevent CPU spike, only query each 100ms
                    Thread.Sleep(100);

                    // Reconnect redis if down
                    if (redisConn == null || !redisConn.IsConnected)
                    {
                        Console.WriteLine("Reconnecting Redis");
                        redisConn = OpenRedisConnection(redisConnectionString);
                        redis = redisConn.GetDatabase();
                    }

                    string json = redis.ListLeftPopAsync("votes").Result;
                    if (json != null)
                    {
                        var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                        Console.WriteLine($"Processing vote for '{vote.vote}' by '{vote.voter_id}'");

                        // Reconnect DB if down
                        if (!pgsql.State.Equals(System.Data.ConnectionState.Open))
                        {
                            Console.WriteLine("Reconnecting DB");
                            pgsql = OpenDbConnection(pgConnectionString);
                        }
                        else
                        { // Normal +1 vote requested
                            UpdateVote(pgsql, vote.voter_id, vote.vote);
                        }
                    }
                    else
                    {
                        keepAliveCommand.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;
            int attemptCount = 0;

            Console.WriteLine("Attempting to connect to PostgreSQL database...");
            
            while (true)
            {
                attemptCount++;
                try
                {
                    Console.WriteLine($"Connection attempt #{attemptCount}...");
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    Console.WriteLine("✓ Database connection successful!");
                    Console.WriteLine($"  Server version: {connection.ServerVersion}");
                    Console.WriteLine($"  Database: {connection.Database}");
                    Console.WriteLine($"  Host: {connection.Host}");
                    break;
                }
                catch (PostgresException pgEx)
                {
                    Console.Error.WriteLine($"✗ PostgreSQL error (attempt #{attemptCount}):");
                    Console.Error.WriteLine($"  Severity: {pgEx.Severity}");
                    Console.Error.WriteLine($"  SqlState: {pgEx.SqlState}");
                    Console.Error.WriteLine($"  Message: {pgEx.Message}");
                    Console.Error.WriteLine($"  Detail: {pgEx.Detail}");
                    Console.Error.WriteLine($"  Hint: {pgEx.Hint}");
                    Thread.Sleep(1000);
                }
                catch (SocketException socketEx)
                {
                    Console.Error.WriteLine($"✗ Network error (attempt #{attemptCount}):");
                    Console.Error.WriteLine($"  SocketErrorCode: {socketEx.SocketErrorCode}");
                    Console.Error.WriteLine($"  Message: {socketEx.Message}");
                    Thread.Sleep(1000);
                }
                catch (DbException dbEx)
                {
                    Console.Error.WriteLine($"✗ Database error (attempt #{attemptCount}):");
                    Console.Error.WriteLine($"  Type: {dbEx.GetType().Name}");
                    Console.Error.WriteLine($"  Message: {dbEx.Message}");
                    if (dbEx.InnerException != null)
                    {
                        Console.Error.WriteLine($"  Inner Exception: {dbEx.InnerException.GetType().Name}: {dbEx.InnerException.Message}");
                    }
                    Thread.Sleep(1000);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"✗ Unexpected error (attempt #{attemptCount}):");
                    Console.Error.WriteLine($"  Type: {ex.GetType().FullName}");
                    Console.Error.WriteLine($"  Message: {ex.Message}");
                    if (ex.InnerException != null)
                    {
                        Console.Error.WriteLine($"  Inner Exception: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
                    }
                    Console.Error.WriteLine($"  Stack Trace:");
                    Console.Error.WriteLine(ex.StackTrace);
                    Thread.Sleep(1000);
                }
            }

            Console.Error.WriteLine("Connected to db");

            var command = connection.CreateCommand();
            command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                        id VARCHAR(255) NOT NULL,
                                        vote VARCHAR(255) NOT NULL
                                    )";
            command.ExecuteNonQuery();

            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(string hostname)
        {
            // Use IP address to workaround https://github.com/StackExchange/StackExchange.Redis/issues/410
            Console.WriteLine($"Resolving Redis hostname: {hostname}");
            var ipAddress = GetIp(hostname);
            Console.WriteLine($"✓ Resolved Redis to {ipAddress}");

            int attemptCount = 0;
            while (true)
            {
                attemptCount++;
                try
                {
                    Console.WriteLine($"Connecting to Redis (attempt #{attemptCount})...");
                    var connection = ConnectionMultiplexer.Connect(ipAddress);
                    Console.WriteLine($"✓ Redis connection successful!");
                    Console.WriteLine($"  Endpoints: {string.Join(", ", connection.GetEndPoints())}");
                    Console.WriteLine($"  Status: {(connection.IsConnected ? "Connected" : "Disconnected")}");
                    return connection;
                }
                catch (RedisConnectionException redisEx)
                {
                    Console.Error.WriteLine($"✗ Redis connection error (attempt #{attemptCount}):");
                    Console.Error.WriteLine($"  Message: {redisEx.Message}");
                    if (redisEx.InnerException != null)
                    {
                        Console.Error.WriteLine($"  Inner Exception: {redisEx.InnerException.Message}");
                    }
                    Thread.Sleep(1000);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"✗ Unexpected Redis error (attempt #{attemptCount}):");
                    Console.Error.WriteLine($"  Type: {ex.GetType().Name}");
                    Console.Error.WriteLine($"  Message: {ex.Message}");
                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
            => Dns.GetHostEntryAsync(hostname)
                .Result
                .AddressList
                .First(a => a.AddressFamily == AddressFamily.InterNetwork)
                .ToString();

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch (DbException)
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                command.ExecuteNonQuery();
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}
