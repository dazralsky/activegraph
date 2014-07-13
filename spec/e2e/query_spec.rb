require 'spec_helper'
require 'set'
class Student; end
class Teacher; end

class Lesson
  include Neo4j::ActiveNode
  property :subject
  property :level

  has_many :teachers, from: Teacher, through: :teaching
  has_many :students, from: Student, through: :is_enrolled_for

  def self.max_level
    self.query_as(:lesson).pluck('max(lesson.level)').first
  end

  def self.level(num)
    self.where(level: num)
  end
end

class Student
  include Neo4j::ActiveNode
  property :name
  property :age, type: Integer

  has_many :lessons, to: Lesson, through: :is_enrolled_for
end

class Teacher
  include Neo4j::ActiveNode
  property :name

  has_many :lessons_teaching, to: Lesson, through: :teaching
  has_many :lessons_taught, to: Lesson, through: :taught

  has_many :lessons, to: Lesson, through_any: true
end

describe 'Query API' do
  before(:each) { delete_db }
  describe 'queries directly on a model class' do
    let!(:samuels) { Teacher.create(name: 'Harold Samuels') }
    let!(:othmar) { Teacher.create(name: 'Ms. Othmar') }

    let!(:ss101) { Lesson.create(subject: 'Social Studies', level: 101) }
    let!(:ss102) { Lesson.create(subject: 'Social Studies', level: 102) }
    let!(:math101) { Lesson.create(subject: 'Math', level: 101) }
    let!(:math201) { Lesson.create(subject: 'Math', level: 201) }
    let!(:geo103) { Lesson.create(subject: 'Geography', level: 103) }

    let!(:sandra) { Student.create(name: 'Sandra', age: 16) }
    let!(:danny) { Student.create(name: 'Danny', age: 15) }
    let!(:bobby) { Student.create(name: 'Bobby', age: 16) }
    before(:each) do
      samuels.lessons_teaching << ss101
      samuels.lessons_teaching << ss102
      samuels.lessons_teaching << geo103
      samuels.lessons_taught << math101

      othmar.lessons_teaching << math101
      othmar.lessons_teaching << math201


      sandra.lessons << math201
      sandra.lessons << ss102

      danny.lessons << math101
      danny.lessons << ss102

      bobby.lessons << ss102
    end
      
    it 'returns all' do
      result = Teacher.to_a

      result.size.should == 2
      result.should include(samuels)
      result.should include(othmar)
    end

    it 'can filter' do
      Teacher.where(name: /.*Othmar.*/).to_a.should == [othmar]
    end

    it 'returns only objects specified by association' do
      samuels.lessons_teaching.to_set.should == [ss101, ss102, geo103].to_set

      samuels.lessons.to_set.should == [ss101, ss102, geo103, math101].to_set
    end

    it 'can filter on associations' do
      samuels.lessons_teaching.where(level: 101).to_a.should == [ss101]

    end

    it 'can call class methods on associations' do
      samuels.lessons_teaching.level(101).to_a.should == [ss101]

      samuels.lessons_teaching.max_level.should == 103
      samuels.lessons_teaching.where(subject: 'Social Studies').max_level.should == 102
    end

    it 'can allow association chaining' do
      result = othmar.lessons_teaching.students.to_set.should == [sandra, danny].to_set

      othmar.lessons_teaching.students.where(age: 16).to_a.should == [sandra]
    end

    it 'can allow for filtering mid-association-chain' do
      othmar.lessons_teaching.where(level: 201).students.to_a.should == [sandra]
    end

    it 'can allow for returning nodes mis-association-chain' do
      othmar.lessons_teaching(:lesson).students.where(age: 16).pluck(:lesson).should == [math201]

      othmar.lessons_teaching(:lesson).students(:student).where(age: 16).pluck(:lesson, :student).should == [[math201], [sandra]]
    end
  end
end

