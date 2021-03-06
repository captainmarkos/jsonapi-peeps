### Demo using JSONAP::Resources for a versioned API

This is my build of the demo app found on the [JSONAPI::Resources](https://jsonapi-resources.com/)
website.


#### Create a new Rails application
```
rails new jsonapi-peeps -d sqlite3 --skip-javascript
```


#### Create the databases
```
bin/rails db:create
```


#### Add the JSONAPI-Resources gem

Add the gem to your Gemfile then run `bundle install`.
```ruby
gem 'jsonapi-resources'
```


#### Application Controller

Make the following changes to application_controller.rb
```ruby
class ApplicationController < ActionController::Base
  include JSONAPI::ActsAsResourceController
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session
end
```
OR
```ruby
class ApplicationController < JSONAPI::ResourceController
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session
end
```
You can also do this on a per controller basis in your app, if only some
controllers will serve the API.


#### Configure Development Environment

Edit `config/environments/development.rb`

Eager loading of classes is recommended. The code will work without it, but
I think it’s the right way to go. See [eager-loading-for-greater-good](http://blog.plataformatec.com.br/2012/08/eager-loading-for-greater-good/)
for more details.
```ruby
# Eager load code on boot so JSONAPI-Resources resources are loaded and processed globally
config.eager_load = true

config.consider_all_requests_local = false
```
This will prevent the server from returning the HTML formatted error messages
when an exception happens. Not strictly necessary, but it makes for nicer
output when debugging using curl or a client library.


#### CORS - optional

You *might* run into CORS issues when accessing from the browser. You can use the
`rack-cors` gem to allow sharing across origins. See [https://github.com/cyu/rack-cors](https://github.com/cyu/rack-cors) for more details.

Add the gem to your Gemfile
```ruby
gem 'rack-cors'
```

Add the CORS middleware to your `config/application.rb`:
```ruby
# Example only, please understand CORS before blindly adding this configuration
# This is not enabled in the peeps source code.
module JsonapiPeeps
  class Application < Rails::Application
    config.middleware.insert_before 0, 'Rack::Cors', :debug => !Rails.env.production?, :logger => (-> { Rails.logger }) do
      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :post, :patch, :delete, :options]
      end
    end
  end
end
```


#### Create Models for our data

Use the standard rails generator to create a model for `Contacts` and one for
related `PhoneNumbers`.
```
rails g model Contact name_first:string name_last:string email:string twitter:string
```

Edit the model
```ruby
class Contact < ActiveRecord::Base
  has_many :phone_numbers

  validates :name_first, presence: true
  validates :name_last, presence: true
end
```

Create the `PhoneNumber` model
```
rails g model PhoneNumber contact_id:integer name:string phone_number:string
```
Edit it
```
class PhoneNumber < ActiveRecord::Base
  belongs_to :contact
end
```


#### Migrate the DB
```
bin/rails db:migrate
```


#### Create Controllers

Use the rails generator to create empty controllers. These will be inherit
methods from the ResourceController so they will know how to respond to the
standard REST methods.
```
rails generate controller Api::V1::Contacts --skip-assets
rails generate controller Api::V1::PhoneNumbers --skip-assets
```


#### Create our resources directory

We need a directory to hold our resources. Let's create it under our app directory.
```
mkdir app/resources
mkdir app/resources/api
mkdir app/resources/api/v1
```


#### Create the resources

Create a new file for each resource. This must be named in a standard way so
it can be found. This should be the single underscored name of the model
with `_resource.rb` appended.  For Contacts this will be `contact_resource.rb`.

Make the the resource files.

```ruby
# app/resources/api/v1/contact_resource.rb

class Api::V1::ContactResource < JSONAPI::Resource
  attributes :name_first, :name_last, :email, :twitter
  has_many :phone_numbers
end
```

```ruby
# app/resources/api/v1/phone_number_resource.rb

class Api::V1::PhoneNumberResource < JSONAPI::Resource
  attributes :name, :phone_number
  has_one :contact

  filter :contact
end
```


#### Setup routes

Add the routes for the new resources
```ruby
  namespace :api do
    namespace :v1 do
      jsonapi_resources :contacts
      jsonapi_resources :phone_numbers
    end
  end
```


#### Test it out

```
bin/rails server
```

Create a new contact:
```
curl -i -H "Accept: application/vnd.api+json" -H 'Content-Type:application/vnd.api+json' -X POST -d '{"data": {"type":"contacts", "attributes":{"name-first":"John", "name-last":"Doe", "email":"john.doe@boring.test"}}}' http://localhost:3000/api/v1/contacts
```

You should get something like this back:
```
HTTP/1.1 201 Created
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 0
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Permitted-Cross-Domain-Policies: none
Referrer-Policy: strict-origin-when-cross-origin
Content-Type: application/vnd.api+json
Location: http://localhost:3000/api/v1/contacts/3
Vary: Accept
ETag: W/"55eef31f5f0ca7fbd286bd8b21e6b7f8"
Cache-Control: max-age=0, private, must-revalidate
X-Request-Id: e8f0dfa4-54da-45e4-b3e5-80f47fadcb1c
X-Runtime: 0.072429
Server-Timing: start_processing.action_controller;dur=0.086181640625, sql.active_record;dur=4.047119140625, instantiation.active_record;dur=0.0400390625, render_template.action_view;dur=0.025390625, process_action.action_controller;dur=16.475830078125
Transfer-Encoding: chunked

{"data":{"id":"3","type":"contacts","links":{"self":"http://localhost:3000/api/v1/contacts/3"},"attributes":{"name-first":"John","name-last":"Doe","email":"john.doe@boring.test","twitter":null},"relationships":{"phone-numbers":{"links":{"self":"http://localhost:3000/api/v1/contacts/3/relationships/phone-numbers","related":"http://localhost:3000/api/v1/contacts/3/phone-numbers"}}}}}
```

Now create a phone number for this contact:
```
curl -i -H "Accept: application/vnd.api+json" -H 'Content-Type:application/vnd.api+json' -X POST -d '{ "data": { "type": "phone-numbers", "relationships": { "contact": { "data": { "type": "contacts", "id": "1" } } }, "attributes": { "name": "home", "phone-number": "(603) 555-1212" } } }' http://localhost:3000/api/v1/phone-numbers
```

And you should get back something like this:
```
HTTP/1.1 201 Created
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 0
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Permitted-Cross-Domain-Policies: none
Referrer-Policy: strict-origin-when-cross-origin
Content-Type: application/vnd.api+json
Location: http://localhost:3000/api/v1/phone-numbers/2
Vary: Accept
ETag: W/"8cfbc58443b08518c019efb5a98045cf"
Cache-Control: max-age=0, private, must-revalidate
X-Request-Id: 22c41173-8f6a-434c-a72e-815ef51b63d9
X-Runtime: 0.030071
Server-Timing: start_processing.action_controller;dur=0.10400390625, sql.active_record;dur=4.553466796875, instantiation.active_record;dur=0.072265625, render_template.action_view;dur=0.032958984375, process_action.action_controller;dur=14.238037109375
Transfer-Encoding: chunked

{"data":{"id":"2","type":"phone-numbers","links":{"self":"http://localhost:3000/api/v1/phone-numbers/2"},"attributes":{"name":"home","phone-number":"(603) 555-1212"},"relationships":{"contact":{"links":{"self":"http://localhost:3000/api/v1/phone-numbers/2/relationships/contact","related":"http://localhost:3000/api/v1/phone-numbers/2/contact"}}}}}
```

You can now query your contacts:
```
curl -H "Accept: application/vnd.api+json" "http://localhost:3000/api/v1/contacts" | json_pp
```
And you would get back something like:
```javascript
{                           
   "data" : [               
      {                     
         "attributes" : {   
            "email" : "john.doe@boring.test",
            "name-first" : "John",
            "name-last" : "Doe",
            "twitter" : null
         },
         "id" : "3",
         "links" : {
            "self" : "http://localhost:3000/api/v1/contacts/3"
         },
         "relationships" : {
            "phone-numbers" : {
               "links" : {
                  "related" : "http://localhost:3000/api/v1/contacts/3/phone-numbers",
                  "self" : "http://localhost:3000/api/v1/contacts/3/relationships/phone-numbers"
               }
            }
         },
         "type" : "contacts"
      }
   ]
}
```

Note that the phone_number id is included in the links, but not the details of
the phone number. You can get these by setting an include:
```
curl -H "Accept: application/vnd.api+json" \
        "http://localhost:3000/api/v1/contacts?include=phone-numbers"
```

Test a validation Error
```
curl 'http://localhost:3000/api/v1/contacts' \
     -H 'Accept: application/vnd.api+json' \
     -H 'Content-Type:application/vnd.api+json' \
     -X POST -d '{ "data": { "type": "contacts", "attributes": { "name-first": "John Doe", "email": "john.doe@boring.test" } } }' | json_pp
```
You should get back something like this:
```javascript
{
   "errors" : [
      {
         "code" : "100",
         "detail" : "name-last - can't be blank",
         "source" : {
            "pointer" : "/data/attributes/name-last"
         },
         "status" : "422",
         "title" : "can't be blank"
      }
   ]
}
```


#### Handling More Data

The earlier responses seem pretty snappy, but they are not really returning a
lot of data. In a real world system there will be a lot more data. Lets mock
some with the faker gem.

Add the `faker` gem to your Gemfile
```ruby
gem 'faker', group: [:development, :test]
```

Let's also add and use the [ruby-progressbar](https://github.com/jfelchner/ruby-progressbar):
```ruby
gem 'ruby-progressbar'
```

Add some seed data using the `db/seeds.rb` file:
```ruby
progressbar = ProgressBar.create(title: 'Creating seed data', total: 40_000)

contacts = 20000.times.map do |_i|
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
```

Now let's create the seed data:
```
bundle install
bin/rails db:seed
```


#### Large requests take to long to complete

Now if we query our contacts we will get a large (20K contacts) dataset back,
and it may run for many seconds.
```
curl -H "Accept: application/vnd.api+json" "http://localhost:3000/api/v1/contacts"
```


#### Options

There are some things we can do to work around this. First we should add a
config file to our initializers. Add a file named `jsonapi_resources.rb` to the
`config/initializers` directory and add this:

```ruby
JSONAPI.configure do |config|
  # Config setting will go here
end
```



#### Caching

We can enable caching so the next request will not require the system to
process all 20K records again.

We first need to turn on caching for the rails portion of the application with
the following:

```
bin/rails dev:cache
```

To enable caching of JSONAPI responses we need to specify which cache to use
(and in version v0.10.x and later that we want all resources cached by default).
So add the following to the initializer you created earlier:
```ruby
JSONAPI.configure do |config|
  config.resource_cache = Rails.cache

  # The following option works in versions v0.10 and later
  #config.default_caching = true
 end
end
```

If using an earlier version than v0.10.x we need to enable caching for each
resource type we want the system to cache. Add the following line to the
`contacts` resource:

```ruby
class Api::V1::ContactResource < JSONAPI::Resource
  caching
  # ...
end
```

If we restart the application and make the same request it will still take the
same amount of time (actually a tiny bit more as the resources are added to the
cache). However if we perform the same request the time should drop
significantly.

We might be able to live with performance of the cached results, but we should
plan for the worst case. So we need another solution to keep our responses
snappy.


#### Pagination

Instead of returning the full result set when the user asks for it, we can break
it into smaller pages of data. That way the server never needs to serialize
every resource in the system at once.

We can add pagination with a config option in the initializer. Add the following
to `config/initializers/jsonapi_resources.rb`:

```ruby
JSONAPI.configure do |config|
  # config.resource_cache = Rails.cache # before v0.10
  config.default_caching = true

  # Options are :none, :offset, :paged, or a custom paginator name
  config.default_paginator = :paged # default is :none

  config.default_page_size = 5 # default is 10
  config.maximum_page_size = 100 # default is 20 
end
```

Restart the app and try the request again:
```
curl -H "Accept: application/vnd.api+json" "http://localhost:3000/api/v1/contacts"
```

Now we only get the first 50 contacts back, and the request is much faster.  And
you will now see a links key with links to get the remaining resources in your
set.  This should look like this:

```javascript
{
  data: [...],

  "links" : {
    "first" : "http://localhost:3000/api/v1/contacts?page%5Bnumber%5D=1&page%5Bsize%5D=5",
    "last" : "http://localhost:3000/api/v1/contacts?page%5Bnumber%5D=4200&page%5Bsize%5D=5",
    "next" : "http://localhost:3000/api/v1/contacts?page%5Bnumber%5D=2&page%5Bsize%5D=5"
  }
}
```

This will allow your client to iterate over the next links to fetch the full
results set without putting extreme pressure on your server.

The default_page_size setting is used if the request does not specify a size,
and the maximum_page_size is used to limit the size the client may request.

Note: The default page sizes are very conservative. There is significant
overhead in making many small requests, and tuning the page sizes should be
considered essential. 
