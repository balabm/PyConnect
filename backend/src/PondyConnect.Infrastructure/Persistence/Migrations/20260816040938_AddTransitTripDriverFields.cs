using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddTransitTripDriverFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DriverName",
                table: "transit_trips",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VehiclePlate",
                table: "transit_trips",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DriverName",
                table: "transit_trips");

            migrationBuilder.DropColumn(
                name: "VehiclePlate",
                table: "transit_trips");
        }
    }
}
