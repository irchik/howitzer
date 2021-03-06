require 'rspec/matchers'
require 'howitzer/mailgun/connector'
require 'howitzer/exceptions'

class Email
  include RSpec::Matchers

  ##
  #
  # Creates new email with message
  #
  # *Parameters:*
  # * +message+ - email message
  #

  def initialize(message)
    @message = message
  end

  ##
  #
  # Search mail by recepient
  #
  # *Parameters:*
  # * +recepient+ - recepient's email address
  #

  def self.find_by_recipient(recipient)
    find(recipient, self::SUBJECT)
  end

  ##
  #
  # Search mail by recepient and subject.
  #
  # *Parameters:*
  # * +recepient+ - recepient's email address
  # * +subject+ - email subject
  #

  def self.find(recipient, subject)
    message = {}
    retryable(timeout: settings.timeout_small, sleep: settings.timeout_short, silent: true, logger: log, on: Howitzer::EmailNotFoundError) do
      events = Mailgun::Connector.instance.client.get("#{Mailgun::Connector.instance.domain}/events", event: 'stored')
      event = events.to_h['items'].find do |hash|
        hash['message']['recipients'].first == recipient && hash['message']['headers']['subject'] == subject
      end
      if event
        message = Mailgun::Connector.instance.client.get("domains/#{Mailgun::Connector.instance.domain}/messages/#{event['storage']['key']}").to_h
      else
        raise Howitzer::EmailNotFoundError.new('Message not received yet, retry...')
      end
    end
    log.error Howitzer::EmailNotFoundError, "Message with subject '#{subject}' for recipient '#{recipient}' was not found." if message.empty?
    new(message)
  end

  ##
  #
  # Returns plain text body of email message
  #

  def plain_text_body
    @message['body-plain']
  end

  ##
  #
  # Returns html body of email message
  #

  def html_body
    @message['stripped-html']
  end

  ##
  #
  # Returns mail text
  #

  def text
    @message['stripped-text']
  end

  ##
  #
  # Returns who has send email data in format: User Name <user@email>
  #

  def mail_from
    @message['From']
  end

  ##
  #
  # Returns array of recipients who has received current email
  #

  def recipients
    @message['To'].split ', '
  end

  ##
  #
  # Returns email received time in format:
  #

  def received_time
    @message['Received'][/\w+, \d+ \w+ \d+ \d+:\d+:\d+ -\d+ \(\w+\)$/]
  end

  ##
  #
  # Returns sender user email
  #

  def sender_email
    @message['sender']
  end

  ##
  #
  # Allows to get email MIME attachment
  #

  def get_mime_part
    files = @message['attachments']
    if files.empty?
      log.error Howitzer::NoAttachmentsError, 'No attachments where found.'
      return
    end
    files
  end
end