using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddConsumerFlags : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "UpdatedAt",
                table: "modifier_groups",
                type: "timestamptz",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "modifier_groups",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(200)",
                oldMaxLength: 200);

            migrationBuilder.AlterColumn<int>(
                name: "MinSelections",
                table: "modifier_groups",
                type: "integer",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer",
                oldDefaultValue: 0);

            migrationBuilder.AlterColumn<int>(
                name: "MaxSelections",
                table: "modifier_groups",
                type: "integer",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer",
                oldDefaultValue: 0);

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "CreatedAt",
                table: "modifier_groups",
                type: "timestamptz",
                nullable: false,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone");

            migrationBuilder.AddColumn<Guid>(
                name: "MenuItemId1",
                table: "modifier_groups",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "consumer_flags",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ConsumerId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    FlagType = table.Column<int>(type: "integer", nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    ShadowBanned = table.Column<bool>(type: "boolean", nullable: false),
                    CodRestricted = table.Column<bool>(type: "boolean", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_consumer_flags", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_modifier_groups_MenuItemId1",
                table: "modifier_groups",
                column: "MenuItemId1");

            migrationBuilder.CreateIndex(
                name: "IX_consumer_flags_ConsumerId",
                table: "consumer_flags",
                column: "ConsumerId");

            migrationBuilder.CreateIndex(
                name: "IX_consumer_flags_ExpiresAt",
                table: "consumer_flags",
                column: "ExpiresAt");

            migrationBuilder.AddForeignKey(
                name: "FK_modifier_groups_menu_items_MenuItemId1",
                table: "modifier_groups",
                column: "MenuItemId1",
                principalTable: "menu_items",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_modifier_groups_menu_items_MenuItemId1",
                table: "modifier_groups");

            migrationBuilder.DropTable(
                name: "consumer_flags");

            migrationBuilder.DropIndex(
                name: "IX_modifier_groups_MenuItemId1",
                table: "modifier_groups");

            migrationBuilder.DropColumn(
                name: "MenuItemId1",
                table: "modifier_groups");

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "UpdatedAt",
                table: "modifier_groups",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamptz",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "modifier_groups",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(100)",
                oldMaxLength: 100);

            migrationBuilder.AlterColumn<int>(
                name: "MinSelections",
                table: "modifier_groups",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<int>(
                name: "MaxSelections",
                table: "modifier_groups",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "CreatedAt",
                table: "modifier_groups",
                type: "timestamp with time zone",
                nullable: false,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamptz");
        }
    }
}
