using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Threading.Tasks;
using CsvHelper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace MyFunctions
{
    public static class CsvToJson
    {
        [FunctionName("NessusReceiver")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("CSVToJSON Azure Function started.");

            try
            {
                // Read the request body
                string csvContent;
                using (StreamReader reader = new StreamReader(req.Body))
                {
                    csvContent = await reader.ReadToEndAsync();
                }

                if (string.IsNullOrWhiteSpace(csvContent))
                {
                    log.LogWarning("Empty CSV content received.");
                    return new BadRequestObjectResult("Request body is empty.");
                }

                // Detect how many non-data lines to skip
                int skipCount = 0;
                using (StringReader sr = new StringReader(csvContent))
                {
                    string? line;
                    while ((line = sr.ReadLine()) != null)
                    {
                        if (!line.Contains(","))
                            skipCount++;
                        else
                            break;
                    }
                }

                log.LogInformation($"Lines skipped: {skipCount}");

                // Convert CSV to JSON
                using (StringReader sr = new StringReader(csvContent))
                {
                    // Skip non-data lines
                    for (int i = 0; i < skipCount; i++)
                        sr.ReadLine();

                    using (var csv = new CsvReader(sr, CultureInfo.InvariantCulture))
                    {
                        var records = csv.GetRecords<dynamic>();
                        string json = JsonConvert.SerializeObject(records, Formatting.Indented);

                        log.LogInformation("CSVToJSON Azure Function completed successfully.");
                        return new OkObjectResult(json);
                    }
                }
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Error occurred while converting CSV to JSON.");
                return new StatusCodeResult((int)HttpStatusCode.InternalServerError);
            }
        }
    }
}