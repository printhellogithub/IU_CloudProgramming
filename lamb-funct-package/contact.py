"""AWS Lambda contact form handler.

Validates incoming form data, sends the message to the service team,
and returns a confirmation email to the user, using AWS SES.
Also returns a HTTP-response to the API-Gateway.
"""

import json
import logging

import boto3
from botocore.exceptions import ClientError
from email_validator import EmailNotValidError, validate_email

# create SES client
SES = boto3.client("ses", region_name="us-east-1")

# create Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)


def lambda_handler(event, context):
    """Process the contact form request and return an API response."""
    logging.info(f"START of Lambda_Handler")
    # logging.info(event)
    # Get data from event
    data = parse_json_and_validate(event=event)
    if not data:
        logging.info(f"400 | Form is not complete.")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Form is not complete."}),
        }
    # validate email
    if not is_valid_email(email=data.get("email")):
        logging.info(f"400 | Email is not valid.")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Email is not valid."}),
        }
    # sending emails
    code = send_emails(data=data)
    if code == 0:
        logging.info(f"SUCCESS of Lambda_Handler - Returning with 200.")
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "message": f"Your message was sent. You will get a confirmation email."
                }
            ),
        }
    elif code == 1:
        logging.info(f"500 | Sending message failed.")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Sending your message failed."}),
        }
    else:
        logging.info(f"500 | Sending confirmation message failed.")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "error": f"Your message was sent to our service, but sending a confirmation to you failed."
                }
            ),
        }


def parse_json_and_validate(event) -> dict:
    """Extract contact form fields from the event-object"""
    body = event.get("body")
    logging.debug(f"Extracted body from event: {body}")
    if not body:
        logging.warning(f"Could not extract body from event.")
        return {}

    try:
        data = json.loads(body)
        logging.debug(f"Extracted data from body: {data}")
    except json.JSONDecodeError as e:
        logging.error(f"JSONDecodeError: {e}")
        return {}

    email = (data.get("email") or "").strip()
    first_name = (data.get("first_name") or "").strip()
    last_name = (data.get("last_name") or "").strip()
    message = (data.get("message") or "").strip()
    logging.debug(
        f"Extracted values from data: email={email}, first_name={first_name}, last_name={last_name}, message={message}"
    )

    if any(not value for value in [email, first_name, last_name, message]):
        logging.info(f"Any value was empty.")
        return {}

    return {
        "email": email,
        "first_name": first_name,
        "last_name": last_name,
        "message": message,
    }


def is_valid_email(email) -> bool:
    """Validate the given user-email-address"""
    try:
        validate_email(email, check_deliverability=True)
        logging.info(f"Email-Validation success.")
        return True
    except EmailNotValidError:
        logging.info(f"EmailNotValidError: {email}")
        return False


def send_emails(data: dict):
    """Send the message to the service-team and the user confirmation email."""
    # write different subjects and messages for service-team and user
    service_subject = f"Service request from {data.get('email')}"
    service_message = f"This message was sent from {data.get('first_name')} {data.get('last_name')} via the contact-formular at cactify.florianjanssens.de.\nRespond to {data.get('email')}.\nMessage:\n \n{data.get('message')}"

    user_subject = f"Your service request at cactify"
    user_message = f"Hello {data.get('first_name')} {data.get('last_name')},\n Your message was sent to our cactify-service-team. Thank you for getting in touch with us.\n We will answer shortly.\n \nYour cactify-team.\n\n Your message: {data.get('message')}"

    try:
        # service-team email
        logging.debug(f"Trying to send Email to service")
        SES.send_email(
            Source="no-reply@cactify.florianjanssens.de",
            Destination={"ToAddresses": ["service@florianjanssens.de"]},
            Message={
                "Subject": {"Data": f"{service_subject}"},
                "Body": {"Text": {"Data": f"{service_message}"}},
            },
            ConfigurationSetName="my-cactify-config-set",
        )
    except ClientError as e:
        logging.error(
            f"AWS ClientError sending to service: {e.response['Error']['Message']}"
        )
        return 1
    try:
        # user confirmation email
        logging.debug(f"Trying to send Email to user")
        SES.send_email(
            Source="no-reply@cactify.florianjanssens.de",
            Destination={"ToAddresses": [str(data.get("email"))]},
            Message={
                "Subject": {"Data": f"{user_subject}"},
                "Body": {"Text": {"Data": f"{user_message}"}},
            },
            ConfigurationSetName="my-cactify-config-set",
        )
        logging.info(f"Emails sent succesfully")
        return 0
    except ClientError as e:
        logging.error(
            f"AWS ClientError sending User-Confirmation-Email: {e.response['Error']['Message']}"
        )
        return 2
