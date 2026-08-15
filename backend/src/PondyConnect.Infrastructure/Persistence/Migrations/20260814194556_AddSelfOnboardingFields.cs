using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSelfOnboardingFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "BankAccountName",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankAccountNumber",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BankIfsc",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FssaiDocUrl",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FssaiNumber",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "GstDocUrl",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "GstNumber",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsKycSubmitted",
                table: "vendors",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "OperatingHours",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PanDocUrl",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PanNumber",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DietaryPreference",
                table: "users",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "HasCompletedOnboarding",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "HasCompletedTutorial",
                table: "drivers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "HasSignedAgreement",
                table: "drivers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "InsuranceUrl",
                table: "drivers",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SelfieUrl",
                table: "drivers",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "TutorialCompletedAt",
                table: "drivers",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BankAccountName",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "BankAccountNumber",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "BankIfsc",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "FssaiDocUrl",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "FssaiNumber",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "GstDocUrl",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "GstNumber",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "IsKycSubmitted",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "OperatingHours",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "PanDocUrl",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "PanNumber",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "DietaryPreference",
                table: "users");

            migrationBuilder.DropColumn(
                name: "HasCompletedOnboarding",
                table: "users");

            migrationBuilder.DropColumn(
                name: "HasCompletedTutorial",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "HasSignedAgreement",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "InsuranceUrl",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "SelfieUrl",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "TutorialCompletedAt",
                table: "drivers");
        }
    }
}
