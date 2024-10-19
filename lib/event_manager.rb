# typed: true
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

$hourly_activity = Array.new(24, 0)

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('google_civic_info_api.key').strip


  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output/thank_you_letters') unless Dir.exist?('output/thank_you_letters')

  filename = "output/thank_you_letters/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.gsub(/\D/, '')
  if not phone_number.length.between?(10, 11)
    return 'invalid'
  end

  if phone_number.length == 11
    if phone_number[0] == "1"
      phone_number = phone_number[1..10]
    else
      return 'invalid'
    end
  end

  "(#{phone_number[0..2]})-#{phone_number[3..5]}-#{phone_number[6..9]}"
end

def record_hourly_activity(registration_date)
  new_time = Time.strptime(registration_date, "%m/%d/%y %R")
  $hourly_activity[new_time.hour] += 1
end

def output_hourly_activity()
  # Create file and headers if needed
  CSV.open("output/hourly_activity.csv", "w") do |csv|
    csv << ['Hour', 'NumberOfRespondants']
    $hourly_activity.each_with_index do |activity_amount, index|
      csv << [index, activity_amount]
    end
  end
end

puts 'EventManager initialized'
Dir.mkdir('output') unless Dir.exist?('output')

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  phone_number = row[:homephone]
  registration_date = row[:regdate]

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  record_hourly_activity(registration_date)
end

output_hourly_activity
