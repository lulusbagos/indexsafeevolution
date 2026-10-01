using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Indexsafe.Api.Services
{
    public class JwtService
    {
        private readonly IConfiguration _config;

        public JwtService(IConfiguration config)
        {
            _config = config;
        }

        public string GenerateToken(
            string nik,
            string fullName,
            string role,
            int companyId,
            string companyName,
            string department,
            string jobTitle,
            int? employeeId = null)
        {
            var secretKey = _config["Jwt:Secret"] ?? "Indexsafe_Evolution_Secret_Key_2026_Enterprise_K3_Mining_Auth_Tokens_Min32Chars!";
            var issuer = _config["Jwt:Issuer"] ?? "Indexsafe.Api";
            var audience = _config["Jwt:Audience"] ?? "Indexsafe.Mobile";
            var expiryDays = int.TryParse(_config["Jwt:ExpiryDays"], out var days) ? days : 30;

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, nik),
                new Claim(ClaimTypes.Name, fullName),
                new Claim(ClaimTypes.Role, role),
                new Claim("CompanyId", companyId.ToString()),
                new Claim("Company", companyName),
                new Claim("Department", department),
                new Claim("JobTitle", jobTitle)
            };

            if (employeeId.HasValue)
            {
                claims.Add(new Claim("EmployeeId", employeeId.Value.ToString()));
            }

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: DateTime.UtcNow.AddDays(expiryDays),
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}
