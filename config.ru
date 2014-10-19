require 'json'
require 'pg'

# SCHEMA
# create table songs (id serial primary key not null, data json not null);

uri = URI.parse(ENV['DATABASE_URL'])
connection = PG::Connection.open host:     uri.host,
                                 user:     uri.user,
                                 password: uri.password,
                                 port:     uri.port || 5432,
                                 dbname:   uri.path[1..-1]

create = -> json do
  result = connection.exec <<-SQL, [json]
    insert into songs (data) values ($1) returning id
  SQL
  JSON.dump result.first
end

index = -> do
  result = connection.exec <<-SQL
    select id from songs
  SQL
  JSON.dump result.to_a
end

show = -> id do
  result = connection.exec <<-SQL, [id]
    select data from songs where id = $1
  SQL
  result.first && result.first['data']
end

not_found = [404, JSON.dump(error: 'not found')]

map '/songs' do
  run -> env do
    route = env.values_at 'REQUEST_METHOD', 'PATH_INFO'
    status, body = case route.join ' '
    when %r[^POST $]
      response = create.call env['rack.input'].read
      [201, response]
    when %r[^GET $]
      [200, index.call]
    when %r[^GET /(?<id>\d+)$]
      song = show[$~[:id]]
      (song && [200, song]) || not_found
    else
      not_found
    end
    [status, {'Content-Type' => 'application/json'}, [body]]
  end
end
