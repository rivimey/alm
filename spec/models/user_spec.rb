require "rails_helper"
require "cancan/matchers"

describe User, type: :model, vcr: true do

  subject { FactoryGirl.create(:user) }

  it { is_expected.to validate_presence_of(:name) }

  context "class methods" do
    it "from_omniauth" do
      auth = OmniAuth.config.mock_auth[:default]
      user = User.from_omniauth(auth)
      expect(user.name).to eq("Josiah Carberry")
    end

    it "fetch_raw_info" do
      subject = FactoryGirl.create(:user, uid: "12345")
      stub = stub_request(:get, "#{ENV["CAS_INFO_URL"]}/#{subject.uid}").to_return(body: File.read(fixture_path + 'cas_raw_info.json'))
      info = User.fetch_raw_info(subject.uid)
      expect(info).to eq(name: "Joe Smith", email: "joe@example.com", nickname: "jsmith", first_name: "Joe", last_name: "Smith")
    end

    it "fetch_raw_info no uid" do
      profile = User.fetch_raw_info(nil)
      expect(profile).to eq(error: "no uid provided")
      expect(profile["realName"]).to be_nil
    end

    it "fetch_raw_info profile not found" do
      subject = FactoryGirl.create(:user, uid: "123")
      stub = stub_request(:get, "#{ENV["CAS_INFO_URL"]}/#{subject.uid}").to_return(body: File.read(fixture_path + 'cas_raw_info_nil.txt'), status: 404)
      profile = User.fetch_raw_info("123")
      expect(profile).to eq(error: "UserProfile not found at authId=123\n", status: 404)
      expect(profile["realName"]).to be_nil
    end
  end

  context "describe admin role" do
    let(:user) { FactoryGirl.create(:user, :role => "admin") }

    it "admin can" do
      ability = Ability.new(user)
      expect(ability).to be_able_to(:manage, Notification.new)
    end
  end

  context "describe staff role" do
    let(:user) { FactoryGirl.create(:user, :role => "staff") }

    it "staff can" do
      ability = Ability.new(user)
      expect(ability).not_to be_able_to(:manage, Notification.new)
      expect(ability).to be_able_to(:read, Notification.new)
    end
  end

  context "describe user role" do
    let(:user) { FactoryGirl.create(:user, :role => "user") }

    it "user can" do
      ability = Ability.new(user)
      expect(ability).not_to be_able_to(:read, Notification.new)
    end
  end
end
