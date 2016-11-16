defmodule CassandraEctoAdapterSpec do
  import Ecto.Query
  use ESpec, async: false
  alias Ecto.Integration.TestRepo
  alias Cassandra.Ecto.Spec.Support.Schemas.{Post}

  context "Adapter behaviour" do
    before do
      case Ecto.Migrator.up(TestRepo, 0, Cassandra.Ecto.Spec.Support.Migrations.PostsMigration, log: false) do
        :already_up -> :ok
        :ok         -> :ok
      end
    end
    context "all/1" do
      it "returns empty list if no data present in database" do
        expect(TestRepo.all(Post)) |> to(eq [])
        expect(TestRepo.all(from p in Post)) |> to(eq [])
      end
      it "returns inserted data" do
        id = Ecto.UUID.bingenerate()
        post = TestRepo.insert!(%Post{
          id: id, title: "hello", tags: ["abra", "cadabra"]
        })
        fetched_post = TestRepo.all(Post) |> List.first
        expect(fetched_post) |> to(eq post)
      end
      it "fails with wrong schema" do
        expect(fn -> TestRepo.all("posts", prefix: "oops") end)
        |> to(raise_exception())
      end
      context "with in clause" do
        let :id, do: Ecto.UUID.bingenerate()
        let :random_ids, do:
          Enum.map((1..3), fn _ -> Ecto.UUID.bingenerate() end)
          |> Enum.to_list
        before do: TestRepo.insert!(%Post{id: id, title: "hello", tags: ["abra", "cadabra"]})

        it "raises error with empty arguments" do
          expect(fn -> TestRepo.all from p in Post, where: p.id in [] end)
          |> to(raise_exception())
        end
        it "fetches nothing with absent ids" do
          [id1, id2, id3] = random_ids
          expect(TestRepo.all from p in Post, where: p.id in [^id1, ^id2, ^id3])
          |> to(eq [])
        end
        it "fetches record with proper id" do
          expect((TestRepo.all from p in Post, where: p.id in [^id]) |> List.first |> Map.get(:id))
          |> to(eq id)
        end
        it "fetches record with proper id and random ids" do
          [id1, id2, _id3] = random_ids
          expect((TestRepo.all from p in Post, where: p.id in [^id, ^id1, ^id2]) |> List.first |> Map.get(:id))
          |> to(eq id)
        end
        it "fetches record by searching value in array field" do
          expect(TestRepo.all((from p in Post, where: "abra" in p.tags), allow_filtering: true) |> List.first |> Map.get(:id))
          |> to(eq id)
        end
      end
    end
    context "when insert/6", focus: true do
      it "inserts record" do
        post = %Post{title: "test", text: "test"}
        post = TestRepo.insert!(post)
        fetched_post = TestRepo.one(Post)
        expect(fetched_post) |> to(eq post)
      end
      it "inserts record with ttl and timestamp" do
        post = %Post{title: "test", text: "test"}
        post = TestRepo.insert!(post, on_conflict: :nothing, ttl: 1000, timestamp: :os.system_time(:micro_seconds))
        fetched_post = TestRepo.one(Post)
        expect(fetched_post) |> to(eq post)
      end
      it "raises error when record already exists with on_conflict: :raise" do
        post = %Post{title: "test", text: "test"}
        post = TestRepo.insert!(post)
        post = %Post{id: post.id, title: "new title", text: "updated text"}
        expect(fn -> TestRepo.insert!(post) end) |> to(raise_exception(ArgumentError))
      end
      it "upserts data with on_conflict: :nothing" do
        post = %Post{title: "test", text: "test"}
        post = TestRepo.insert!(post)
        post = %Post{id: post.id, title: "new title", text: "updated text"}
        post = TestRepo.insert!(post, on_conflict: :nothing)
        fetched_post = TestRepo.one(Post)
        expect(fetched_post) |> to(eq post)
      end
    end
    context "when update/6" do
      it "updates record" do
        post = %Post{title: "test", text: "test"}
        post = TestRepo.insert!(post)
        post = Ecto.Changeset.change post, text: "updated text"
        post = TestRepo.update!(post)
        fetched_post = TestRepo.one(Post)
        expect(fetched_post) |> to(eq post)
      end
      it "upserts data always" do
        post = %Post{id: Ecto.UUID.bingenerate()}
        |> Ecto.Changeset.cast(%{title: "test", text: "upserted text"}, [:title, :text])
        |> TestRepo.update!
        fetched_post = TestRepo.one(Post)
        expect(fetched_post) |> to(eq post)
      end
    end
    context "when delete/4" do
      it "deletes record" do
        post = %Post{title: "test", text: "test"}
        post = TestRepo.insert!(post)
        TestRepo.delete!(post)
        expect(TestRepo.all(Post) |> Enum.count) |> to(eq 0)
      end
    end
  end
end
