defmodule CreateViewTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateView

  test "create view" do
    expected = %{
      name: ["chat", "raw_assignment"]
    }
    assert {:ok, expected} == CreateView.parse("""
    CREATE VIEW chat.raw_assignment AS
     WITH users AS (
             SELECT u.id,
                u.warp_avatar_id,
                u.is_active,
                u.is_student,
                u.surname,
               FROM (public.click_user u
                 JOIN public.warp_avatar a ON ((a.id = u.warp_avatar_id)))
            )
     SELECT DISTINCT p.id AS patient_id,
        first_value(c.id) OVER w AS care_taker_id,
        first_value(cf.facility_id) OVER w AS facility_id,
        first_value(cf.role_name) OVER w AS role_name
       FROM (((users c
         JOIN public.facility_user cf ON ((cf.user_id = c.id)))
         JOIN public.facility_user pf ON ((pf.facility_id = cf.facility_id)))
         JOIN users p ON ((p.id = pf.user_id)))
      WHERE (((cf.role_name)::text <> 'patient'::text) AND ((pf.role_name)::text = 'patient'::text))
      WINDOW w AS (PARTITION BY p.id ORDER BY cf.created_at);
    """)

    expected = %{
      name: ["chat", "internal_assignment"]
    }
    assert {:ok, expected} == CreateView.parse("""
    CREATE VIEW chat.internal_assignment AS
     SELECT raw_assignment.patient_id AS assignee_id,
        raw_assignment.care_taker_id AS user_id,
        raw_assignment.facility_id,
        raw_assignment.role_name
       FROM chat.raw_assignment
      WHERE (NOT (raw_assignment.patient_id IN ( SELECT raw_assignment_1.care_taker_id
               FROM chat.raw_assignment raw_assignment_1)));
    """)
  end

end

