variable "s3_website_content_bucket_name" {
  description = "S3 Bucket containing website contents, origin of cloudfront distribution"
  type        = string
  default     = "cactify-website-content"
}

variable "s3_lambda_bucket_name" {
  description = "S3 Bucket containing lambda function"
  type        = string
  default     = "cactify-lambda-bucket"
}

# Für den/die Tester*in dieser Software: Hier wird eine in Route53 registrierte Domain (florianjanssens.de) verwendet. 
# Für Testzwecke muss eine eigene bei Route53 registrierte/verwaltete Domain verwendet werden. 
# Diese sollte hier als main_domain Variable angegeben werden.
# Für dieses Projekt wird eine Subdomain nach dem Schema cactify.DOMAIN durch die Terraform-Konfiguration in Route53 angelegt. 
variable "domain_config" {
  type = object({
    main_domain = string
    subdomain   = string
  })
  default = {
    main_domain = "florianjanssens.de"
    subdomain   = "cactify"
  }
}

# Für den/die Tester*in dieser Software: Geben Sie hier Ihre Email-Adresse als default-value ein, damit ihre Email-Adresse verifiziert werden kann. 
# Sobald die Terraform-Konfiguration applied wird, wird sich Amazon SES im Sandbox-Modus befinden. Nur an verifizierte Email-Adressen können 
# im Sandbox-Modus Emails versendet werden. Um die Email-Adresse zu verifizieren, folgen Sie den Anweisungen in der Bestätigungs-Email von Amazon SES.
# Ist Ihre Email-Adresse verifiziert, können Sie diese zum Testen im Kontaktformular der gehosteten Website nutzen.
variable "test_email_for_ses" {
  type        = string
  description = "Verified SES Test Email for Sandbox Mode."
  default     = "contact@florianjanssens.de"
}