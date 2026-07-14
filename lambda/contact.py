# from email_validator import validate_email, EmailNotValidError

def lambda_handler(event, context):
    print(event)
    return 'Hello from Lambda!'


# def is_valid_email(email):
#     try:
#         validate_email(email)
#         return True
#     except(EmailNotValidError):
#         return False


# 1. JSON parsen in first_name, last_name, email, message
# 2. Checken ob ein Feld leer ist.
# 3. Checken ob Email gültig ist. (regex?)
# 4. E-Mail an Service-Team
# 5. Bestätigungsmail an Nutzer
# 6. Rückmeldung Erfolg/Fehler
