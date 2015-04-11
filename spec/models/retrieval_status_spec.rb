require 'rails_helper'

describe RetrievalStatus, type: :model, vcr: true do
  before(:each) { allow(Time.zone).to receive(:now).and_return(Time.mktime(2015, 4, 8)) }

  it { is_expected.to belong_to(:work) }
  it { is_expected.to belong_to(:source) }

  describe "use stale_at" do
    subject { FactoryGirl.create(:retrieval_status) }

    it "stale_at should be a datetime" do
      expect(subject.stale_at).to be_a_kind_of Time
    end

    it "stale_at should be in the future" do
      expect(subject.stale_at - Time.zone.now).to be > 0
    end

    it "stale_at should be after work publication date" do
      expect(subject.stale_at - subject.work.published_on.to_datetime).to be > 0
    end
  end

  describe "staleness intervals" do
    it "published a day ago" do
      date = Time.zone.now - 1.day
      work = FactoryGirl.create(:work, year: date.year, month: date.month, day: date.day)
      subject = FactoryGirl.create(:retrieval_status, :work => work)
      duration = subject.source.staleness[0]
      expect(subject.stale_at - Time.zone.now).to be_within(0.11 * duration).of(duration)
    end

    it "published 8 days ago" do
      date = Time.zone.now - 8.days
      work = FactoryGirl.create(:work, year: date.year, month: date.month, day: date.day)
      subject = FactoryGirl.create(:retrieval_status, :work => work)
      duration = subject.source.staleness[1]
      expect(subject.stale_at - Time.zone.now).to be_within(0.11 * duration).of(duration)
    end

    it "published 32 days ago" do
      date = Time.zone.now - 32.days
      work = FactoryGirl.create(:work, year: date.year, month: date.month, day: date.day)
      subject = FactoryGirl.create(:retrieval_status, :work => work)
      duration = subject.source.staleness[2]
      expect(subject.stale_at - Time.zone.now).to be_within(0.11 * duration).of(duration)
    end

    it "published 370 days ago" do
      date = Time.zone.now - 370.days
      work = FactoryGirl.create(:work, year: date.year, month: date.month, day: date.day)
      subject = FactoryGirl.create(:retrieval_status, :work => work)
      duration = subject.source.staleness[3]
      expect(subject.stale_at - Time.zone.now).to be_within(0.15 * duration).of(duration)
    end
  end

  describe "retrieved_days_ago" do
    it "today" do
      subject = FactoryGirl.create(:retrieval_status, retrieved_at: Time.zone.now)
      expect(subject.retrieved_days_ago).to eq(1)
    end

    it "two days" do
      subject = FactoryGirl.create(:retrieval_status, retrieved_at: Time.zone.now - 2.days)
      expect(subject.retrieved_days_ago).to eq(2)
    end

    it "never" do
      subject = FactoryGirl.create(:retrieval_status, retrieved_at: Date.new(1970, 1, 1))
      expect(subject.retrieved_days_ago).to eq(1)
    end
  end

  describe "get_events_previous_day" do
    it "no days" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref)
      expect(subject.get_events_previous_day).to eq(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 0)
    end

    it "current day" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_current_day)
      expect(subject.get_events_previous_day).to eq(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 0)
    end

    it "last day" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_last_day)
      expect(subject.get_events_previous_day).to eq(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 20)
    end
  end

  describe "get_events_current_day" do
    it "no days" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref)
      expect(subject.get_events_current_day).to eq(year: 2015, month: 4, day: 8, pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 25)
    end

    it "current day" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_current_day)
      expect(subject.get_events_current_day).to eq(year: 2015, month: 4, day: 8, pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 20)
    end

    it "last day" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_last_day)
      expect(subject.get_events_current_day).to eq(year: 2015, month: 4, day: 8, pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 5)
    end
  end

  describe "get_events_previous_month" do
    it "no months" do
      subject = FactoryGirl.create(:retrieval_status)
      expect(subject.get_events_previous_month).to eq(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 0)
    end

    it "current month" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_current_month)
      expect(subject.get_events_previous_month).to eq(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 0)
    end

    it "last month" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_last_month)
      expect(subject.get_events_previous_month).to eq(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 20)
    end
  end

  describe "get_events_current_month" do
    it "no days" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref)
      expect(subject.get_events_current_month).to eq(year: 2015, month: 4, pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 25)
    end

    it "current month" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_current_month)
      expect(subject.get_events_current_month).to eq(year: 2015, month: 4, pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 20)
    end

    it "last month" do
      subject = FactoryGirl.create(:retrieval_status, :with_crossref_last_month)
      expect(subject.get_events_current_month).to eq(year: 2015, month: 4, pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, total: 5)
    end
  end

  describe "update_works" do
    subject { FactoryGirl.create(:retrieval_status, :with_crossref) }

    it "no works" do
      data = []
      expect(subject.update_works(data)).to be_empty
    end

    it "work from CrossRef" do
      related_work = FactoryGirl.create(:work, doi: "10.1371/journal.pone.0043007")
      relation_type = FactoryGirl.create(:relation_type)
      data = [{"author"=>[{"family"=>"Occelli", "given"=>"Valeria"}, {"family"=>"Spence", "given"=>"Charles"}, {"family"=>"Zampini", "given"=>"Massimiliano"}], "title"=>"Audiotactile Interactions In Temporal Perception", "container-title"=>"Psychonomic Bulletin & Review", "issued"=>{"date-parts"=>[[2011]]}, "DOI"=>"10.3758/s13423-011-0070-4", "volume"=>"18", "issue"=>"3", "page"=>"429", "type"=>"article-journal", "related_works"=>[{"related_work"=>"doi:10.1371/journal.pone.0043007", "source"=>"crossref", "relation_type"=>"cites"}]}]
      expect(subject.update_works(data)).to eq(["doi:10.3758/s13423-011-0070-4"])

      expect(Work.count).to eq(4)
      work = Work.last
      expect(work.title).to eq("Audiotactile Interactions In Temporal Perception")
      expect(work.pid).to eq("doi:10.3758/s13423-011-0070-4")

      expect(work.references.length).to eq(1)
      expect(work.references.first.relation_type.name).to eq(relation_type.name)

      expect(work.referenced_works.length).to eq(1)
      expect(work.referenced_works.first).to eq(related_work)
    end
  end

  context "perform_get_data" do
    let(:work) { FactoryGirl.create(:work, doi: "10.1371/journal.pone.0115074", year: 2014, month: 12, day: 16) }
    let!(:relation_type) { FactoryGirl.create(:relation_type, name: "bookmarks") }
    subject { FactoryGirl.create(:retrieval_status, total: 2, readers: 2, work: work) }

    it "success" do
      expect(subject.months.count).to eq(0)
      expect(subject.perform_get_data).to eq(total: 4, html: 0, pdf: 0, previous_total: 2, skipped: false, update_interval: 31)
      expect(subject.total).to eq(4)
      expect(subject.readers).to eq(4)
      expect(subject.months.count).to eq(2)
      expect(subject.days.count).to eq(2)

      month = subject.months.last
      expect(month.year).to eq(2015)
      expect(month.month).to eq(1)
      expect(month.total).to eq(2)
      expect(month.readers).to eq(2)

      day = subject.days.last
      expect(day.year).to eq(2014)
      expect(day.month).to eq(12)
      expect(day.day).to eq(30)
      expect(day.total).to eq(1)
      expect(day.readers).to eq(1)

      expect(Relation.count).to eq(4)
      relation = Relation.first
      expect(relation.relation_type.name).to eq("bookmarks")
      expect(relation.source.name).to eq("citeulike")
      expect(relation.related_work.pid).to eq(work.pid)
    end

    it "success counter" do
      work = FactoryGirl.create(:work, :doi => "10.1371/journal.pone.0116034")
      source = FactoryGirl.create(:counter)
      subject = FactoryGirl.create(:retrieval_status, total: 50, pdf: 10, html: 40, work: work, source: source)

      expect(subject.months.count).to eq(0)
      expect(subject.perform_get_data).to eq(total: 148, html: 116, pdf: 22, previous_total: 50, skipped: false, update_interval: 31)
      expect(subject.total).to eq(148)
      expect(subject.pdf).to eq(22)
      expect(subject.html).to eq(116)
      expect(subject.months.count).to eq(5)
      expect(subject.days.count).to eq(0)
      expect(subject.extra.length).to eq(5)

      month = subject.months.last
      expect(month.year).to eq(2015)
      expect(month.month).to eq(4)
      expect(month.total).to eq(1)
      expect(month.pdf).to eq(0)
      expect(month.html).to eq(1)

      extra = subject.extra.last
      expect(extra).to eq("month"=>"4", "year"=>"2015", "pdf_views"=>0, "xml_views"=>0, "html_views"=>"1")
    end

    it "success no data" do
      work = FactoryGirl.create(:work, :doi => "10.1371/journal.pone.0116034")
      subject = FactoryGirl.create(:retrieval_status, total: 2, readers: 2, work: work)

      expect(subject.months.count).to eq(0)
      expect(subject.perform_get_data).to eq(total: 0, html: 0, pdf: 0, previous_total: 2, skipped: false, update_interval: 31)
      expect(subject.total).to eq(0)
      expect(subject.readers).to eq(0)
      expect(subject.months.count).to eq(1)

      month = subject.months.last
      expect(month.year).to eq(2015)
      expect(month.month).to eq(4)
      expect(month.total).to eq(2)
      expect(month.readers).to eq(2)

      expect(Relation.count).to eq(0)
    end

    it "error" do
      stub = stub_request(:get, subject.source.get_query_url(subject.work)).to_return(:status => [408])
      expect(subject.perform_get_data).to eq(total: 2, html: 0, pdf: 0, previous_total: 2, skipped: true, update_interval: 31)
      expect(subject.total).to eq(2)
      expect(subject.readers).to eq(2)
      expect(subject.months.count).to eq(0)
    end
  end
end
