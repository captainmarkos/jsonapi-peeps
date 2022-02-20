progressbar = ProgressBar.create(title: 'Creating seed data', total: 1_000)

contacts = 500.times.map do |_i|
  progressbar.increment

  Contact.create({
    name_first: Faker::Name.first_name,
    name_last: Faker::Name.last_name,
    email: Faker::Internet.safe_email,
    twitter: "@#{Faker::Internet.user_name}"
  })
end

contacts.each do |contact|
  progressbar.increment

  contact.phone_numbers.create({
    name: 'cell',
    phone_number: Faker::PhoneNumber.cell_phone
  })

  contact.phone_numbers.create({
    name: 'home',
    phone_number: Faker::PhoneNumber.phone_number
  })
end
