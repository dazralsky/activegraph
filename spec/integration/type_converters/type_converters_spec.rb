describe ActiveGraph::Shared::TypeConverters do
  describe 'converters' do
    it 'has converters for DateTime' do
      expect(ActiveGraph::Shared::TypeConverters::CONVERTERS[DateTime]).to eq(ActiveGraph::Shared::TypeConverters::DateTimeConverter)
    end

    it 'has converters for JSON' do
      expect(ActiveGraph::Shared::TypeConverters::CONVERTERS[JSON]).to eq(ActiveGraph::Shared::TypeConverters::JSONConverter)
    end

    it 'has converters for YAML' do
      expect(ActiveGraph::Shared::TypeConverters::CONVERTERS[Hash]).to eq(ActiveGraph::Shared::TypeConverters::YAMLConverter)
    end
  end

  describe 'to_ruby' do
    it 'converts if there is a converter' do
      date_time = Time.utc(2011, 3, 2, 10, 0, 0).to_i
      converter_value = ActiveGraph::Shared::TypeConverters.to_other(:to_ruby, date_time, DateTime)
      expect(converter_value).to be_a(DateTime)
      expect(converter_value.year).to eq(2011)
      expect(converter_value.month).to eq(3)
      expect(converter_value.day).to eq(2)
      expect(converter_value.hour).to eq(10)
    end

    it 'returns the same value if there is no converter' do
      expect(ActiveGraph::Shared::TypeConverters.to_other(:to_ruby, 42, Integer)).to eq(42)
    end
  end

  describe 'to_db' do
    it 'converts if there is a converter' do
      date_time = DateTime.civil(2011, 3, 4, 1, 2, 3, 0)
      converter_value = ActiveGraph::Shared::TypeConverters.to_other(:to_db, date_time, DateTime)
      expect(converter_value).to be_a(Integer)
    end

    it 'returns the same value if there is no converter' do
      expect(ActiveGraph::Shared::TypeConverters.to_other(:to_ruby, 42, Integer)).to eq(42)
    end

    it 'returns the same value if it is already of the expected type' do
      timestamp = DateTime.now.to_i
      expect(ActiveGraph::Shared::TypeConverters.to_other(:to_db, timestamp, DateTime)).to eq timestamp
    end
  end

  describe 'Integer' do
    subject { ActiveGraph::Shared::TypeConverters::IntegerConverter }

    it 'translates from and to database' do
      db_value = subject.to_db('1')
      ruby_value = subject.to_ruby('1')
      [db_value, ruby_value].each do |i|
        expect(i).to be_a(Integer)
        expect(i).to eq 1
      end
    end
  end

  describe 'Float' do
    subject { ActiveGraph::Shared::TypeConverters::FloatConverter }

    it 'translates from and to database' do
      db_value = subject.to_db('1')
      ruby_value = subject.to_ruby('1')
      [db_value, ruby_value].each do |i|
        expect(i).to be_a(Float)
        expect(i).to eq 1.0
      end
    end
  end

  describe 'String' do
    subject { ActiveGraph::Shared::TypeConverters::StringConverter }

    describe '#to_db and #to_ruby' do
      it 'calls to_s on the object' do
        expect(subject.to_db(1)).to eq '1'
        expect(subject.to_ruby(1)).to eq '1'
      end
    end
  end

  # These tests originally from ActiveAttr gem
  describe 'Boolean' do
    subject { ActiveGraph::Shared::TypeConverters::BooleanConverter }

    describe '#converted?' do
      def converted?(value)
        ActiveGraph::Shared::TypeConverters::BooleanConverter.converted?(value)
      end

      it do
        [true, false].each { |bool| expect(converted?(bool)).to eq true }
        %w(true false).each { |string| expect(converted?(string)).to eq false }
      end
    end

    describe '#to_db' do
      it 'returns true for true' do
        expect(subject.to_db(true)).to equal true
      end

      it 'returns false for false' do
        expect(subject.to_db(false)).to equal false
      end

      it 'casts nil to false' do
        expect(subject.to_db(nil)).to equal false
      end

      it 'casts an Object to true' do
        expect(subject.to_db(Object.new)).to equal true
      end

      context 'when the value is a String' do
        it 'casts an empty String to false' do
          expect(subject.to_db('')).to equal false
        end

        it 'casts a non-empty String to true' do
          expect(subject.to_db('abc')).to equal true
        end

        {
          't' => true,
          'f' => false,
          'T' => true,
          'F' => false,
          # http://yaml.org/type/bool.html
          'y' => true,
          'Y' => true,
          'yes' => true,
          'Yes' => true,
          'YES' => true,
          'n' => false,
          'N' => false,
          'no' => false,
          'No' => false,
          'NO' => false,
          'true' => true,
          'True' => true,
          'TRUE' => true,
          'false' => false,
          'False' => false,
          'FALSE' => false,
          'on' => true,
          'On' => true,
          'ON' => true,
          'off' => false,
          'Off' => false,
          'OFF' => false
        }.each_pair do |value, result|
          it "casts #{value.inspect} to #{result.inspect}" do
            expect(subject.to_db(value)).to equal result
          end
        end
      end

      context 'when the value is Numeric' do
        it 'casts 0 to false' do
          expect(subject.to_db(0)).to equal false
        end

        it 'casts 1 to true' do
          expect(subject.to_db(1)).to equal true
        end

        it 'casts 0.0 to false' do
          expect(subject.to_db(0.0)).to equal false
        end

        it 'casts 0.1 to true' do
          expect(subject.to_db(0.1)).to equal true
        end

        it 'casts a zero BigDecimal to false' do
          expect(subject.to_db(BigDecimal('0.0'))).to equal false
        end

        it 'casts a non-zero BigDecimal to true' do
          expect(subject.to_db(BigDecimal('0.1'))).to equal true
        end

        it 'casts -1 to true' do
          expect(subject.to_db(-1)).to equal true
        end

        it 'casts -0.0 to false' do
          expect(subject.to_db(-0.0)).to equal false
        end

        it 'casts -0.1 to true' do
          expect(subject.to_db(-0.1)).to equal true
        end

        it 'casts a negative zero BigDecimal to false' do
          expect(subject.to_db(BigDecimal('-0.0'))).to equal false
        end

        it 'casts a negative BigDecimal to true' do
          expect(subject.to_db(BigDecimal('-0.1'))).to equal true
        end
      end

      context 'when the value is the String version of a Numeric' do
        it "casts '0' to false" do
          expect(subject.to_db('0')).to equal false
        end

        it "casts '1' to true" do
          expect(subject.to_db('1')).to equal true
        end

        it "casts '0.0' to false" do
          expect(subject.to_db('0.0')).to equal false
        end

        it "casts '0.1' to true" do
          expect(subject.to_db('0.1')).to equal true
        end

        it "casts '-1' to true" do
          expect(subject.to_db('-1')).to equal true
        end

        it "casts '-0.0' to false" do
          expect(subject.to_db('-0.0')).to equal false
        end

        it "casts '-0.1' to true" do
          expect(subject.to_db('-0.1')).to equal true
        end
      end
    end
  end

  describe ActiveGraph::Shared::TypeConverters::JSONConverter do
    subject { ActiveGraph::Shared::TypeConverters::JSONConverter }

    let(:links) { {neo4j: 'http://www.neo4j.org', neotech: 'http://www.neotechnology.com/'} }

    it 'translates from and to database' do
      db_value = ActiveGraph::Shared::TypeConverters::JSONConverter.to_db(links)
      ruby_value = ActiveGraph::Shared::TypeConverters::JSONConverter.to_ruby(db_value)
      expect(db_value.class).to eq String
      expect(ruby_value.class).to eq Hash
      expect(ruby_value['neo4j']).to eq 'http://www.neo4j.org'
    end

    context 'various type combinations' do
      before do
        stub_active_node_class('JsonData') do
          property :serialized_property
          serialize :serialized_property
        end
      end

      let(:json_data) { JsonData.create(serialized_property: value) }

      subject { JsonData.find(json_data.id).serialized_property }

      let_context value: 123 do
        it { is_expected.to eq 123 }
      end

      let_context value: [:array, :of, :symbols] do
        it { is_expected.to eq %w(array of symbols) }
      end

      let_context value: 'expected string' do
        it { is_expected.to eq 'expected string' }
      end

      let_context value: {hashy: :mc_hasher} do
        it { is_expected.to eq('hashy' => 'mc_hasher') }
      end

      let_context value: ['mixed', :values, 1337, {of: :things}] do
        it { is_expected.to eq ['mixed', 'values', 1337, {'of' => 'things'}] }
      end
    end
  end

  describe ActiveGraph::Shared::TypeConverters::YAMLConverter do
    subject { ActiveGraph::Shared::TypeConverters::YAMLConverter }

    let(:links) { {neo4j: 'http://www.neo4j.org', neotech: 'http://www.neotechnology.com/'} }

    it 'translates from and to database' do
      db_value = ActiveGraph::Shared::TypeConverters::YAMLConverter.to_db(links)
      ruby_value = ActiveGraph::Shared::TypeConverters::YAMLConverter.to_ruby(db_value)
      expect(db_value.class).to eq String
      expect(ruby_value.class).to eq Hash
      expect(ruby_value[:neo4j]).to eq 'http://www.neo4j.org'
    end
  end

  describe ActiveGraph::Shared::TypeConverters::DateTimeConverter do
    subject { ActiveGraph::Shared::TypeConverters::DateTimeConverter }

    before(:each) do
      @dt = 1_352_538_487
      @hr = 3600
    end

    its(:to_db, DateTime.parse('2012-11-10T09:08:07-06:00')) { is_expected.to eq(@dt + 6 * @hr) }
    its(:to_db, DateTime.parse('2012-11-10T09:08:07-04:00')) { is_expected.to eq(@dt + 4 * @hr) }
    its(:to_db, DateTime.parse('2012-11-10T09:08:07-02:00')) { is_expected.to eq(@dt + 2 * @hr) }
    its(:to_db, DateTime.parse('2012-11-10T09:08:07+00:00')) { is_expected.to eq(@dt) }
    its(:to_db, DateTime.parse('2012-11-10T09:08:07+02:00')) { is_expected.to eq(@dt - 2 * @hr) }
    its(:to_db, DateTime.parse('2012-11-10T09:08:07+04:00')) { is_expected.to eq(@dt - 4 * @hr) }
    its(:to_db, DateTime.parse('2012-11-10T09:08:07+06:00')) { is_expected.to eq(@dt - 6 * @hr) }

    describe 'to_ruby' do
      it 'translate a Integer back to DateTime' do
        expect(subject.to_ruby(@dt + 6 * @hr)).to eq(DateTime.parse('2012-11-10T09:08:07-06:00'))
      end

      it 'translate a String back to DateTime' do
        expect(subject.to_ruby(Time.at(@dt - 6 * @hr).to_datetime.to_s)).to eq(DateTime.parse('2012-11-10T09:08:07+06:00'))
      end
    end

    it 'translate from and to database' do
      value = DateTime.parse('2012-11-10T09:08:07+00:00') # only utc support
      db_value = ActiveGraph::Shared::TypeConverters::DateTimeConverter.to_db(value)
      ruby_value = ActiveGraph::Shared::TypeConverters::DateTimeConverter.to_ruby(db_value)
      expect(ruby_value.class).to eq(DateTime)
      expect(ruby_value.to_s).to eq(value.to_s)
    end
  end
end
