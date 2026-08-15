using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminActionLog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "admin_action_logs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AdminUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActionType = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    EntityType = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    EntityId = table.Column<Guid>(type: "uuid", nullable: true),
                    Payload = table.Column<string>(type: "jsonb", nullable: true),
                    IpAddress = table.Column<string>(type: "character varying(45)", maxLength: 45, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_admin_action_logs", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_admin_action_logs_ActionType",
                table: "admin_action_logs",
                column: "ActionType");

            migrationBuilder.CreateIndex(
                name: "IX_admin_action_logs_AdminUserId",
                table: "admin_action_logs",
                column: "AdminUserId");

            migrationBuilder.CreateIndex(
                name: "IX_admin_action_logs_CreatedAt",
                table: "admin_action_logs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_admin_action_logs_EntityType_EntityId",
                table: "admin_action_logs",
                columns: new[] { "EntityType", "EntityId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "admin_action_logs");
        }
    }
}
