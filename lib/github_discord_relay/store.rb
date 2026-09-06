require "fileutils"
require "digest"
require "sequel"

module GithubDiscordRelay
  RelayUser = Struct.new(:name, :channel_id, :active, keyword_init: true)

  class Store
    def initialize(database_path)
      FileUtils.mkdir_p(File.dirname(File.expand_path(database_path)))
      @db = Sequel.sqlite(database_path)
      @db.create_table? :relay_users do
        String :name, primary_key: true, size: 64
        String :token_hash, null: false, unique: true, size: 64
        Bignum :channel_id, null: false
        TrueClass :active, null: false, default: true
      end
      @users = @db[:relay_users]
    end

    def self.hash_token(token)
      Digest::SHA256.hexdigest(token)
    end

    def create_user(name, channel_id)
      token = SecureRandom.urlsafe_base64(32)
      @users.insert(name: name, token_hash: self.class.hash_token(token), channel_id: channel_id)
      [token, find(name)]
    end

    def find_by_token(token)
      row = @users.where(token_hash: self.class.hash_token(token), active: true).first
      row && user_from(row)
    end

    def set_active(name, active)
      @users.where(name: name).update(active: active) == 1
    end

    def find(name)
      row = @users.where(name: name).first
      row && user_from(row)
    end

    def list_users
      @users.order(:name).all.map { |row| user_from(row) }
    end

    private

    def user_from(row)
      RelayUser.new(name: row[:name], channel_id: row[:channel_id], active: row[:active])
    end
  end
end
