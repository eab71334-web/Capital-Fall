using UnityEngine;

// المرحلة 1: جندي بسلاح. كل شيء ينبني بالكود، ما نحتاج نعدل مشهد.
public class GameBootstrap
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.transform.localScale = new Vector3(20, 1, 20);
        ground.GetComponent<Renderer>().material.color = new Color(.25f, .4f, .2f);

        var sun = new GameObject("Sun").AddComponent<Light>();
        sun.type = LightType.Directional;
        sun.transform.rotation = Quaternion.Euler(50, -30, 0);

        for (int i = 0; i < 25; i++) // مباني/صناديق للتغطية
        {
            var b = GameObject.CreatePrimitive(PrimitiveType.Cube);
            b.transform.position = new Vector3(Random.Range(-80, 80), 2, Random.Range(-80, 80));
            b.transform.localScale = new Vector3(Random.Range(3, 8), 4, Random.Range(3, 8));
            b.GetComponent<Renderer>().material.color = Color.gray;
        }

        var p = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        p.name = "Soldier";
        Object.Destroy(p.GetComponent<Collider>());
        p.GetComponent<Renderer>().material.color = new Color(.2f, .35f, .2f);
        p.transform.position = new Vector3(0, 1, 0);
        p.AddComponent<CharacterController>();
        var gun = GameObject.CreatePrimitive(PrimitiveType.Cube);
        Object.Destroy(gun.GetComponent<Collider>());
        gun.transform.SetParent(p.transform);
        gun.transform.localPosition = new Vector3(.4f, .2f, .6f);
        gun.transform.localScale = new Vector3(.12f, .12f, .9f);
        gun.GetComponent<Renderer>().material.color = Color.black;
        p.AddComponent<Soldier>();

        if (Camera.main == null)
        {
            var c = new GameObject("Cam").AddComponent<Camera>();
            c.tag = "MainCamera";
        }
        for (int i = 0; i < 6; i++) Enemy.Spawn();
    }
}

public class Soldier : MonoBehaviour
{
    public static Soldier I;
    public float hp = 100; public int kills;
    float yaw, pitch = 15, vy, nextFire;
    CharacterController cc;
    int moveId = -1; Vector2 moveOrigin, moveVec; bool firing;

    void Awake() { I = this; cc = GetComponent<CharacterController>(); }

    void Update()
    {
        if (hp <= 0) { if (Input.touchCount > 0 || Input.GetKeyDown(KeyCode.R)) { hp = 100; kills = 0; transform.position = new Vector3(0, 1, 0); } return; }
        float W = Screen.width, H = Screen.height;
        Vector2 mv = new Vector2(Input.GetAxis("Horizontal"), Input.GetAxis("Vertical"));
        firing = Input.GetMouseButton(0) && Input.touchCount == 0;
        bool moveSeen = false;
        foreach (var t in Input.touches)
        {
            Vector2 pos = t.position;
            if ((pos - new Vector2(W * .85f, H * .2f)).magnitude < H * .12f) { firing = true; continue; }
            if (pos.x < W * .45f && (t.fingerId == moveId || moveId == -1))
            {
                if (t.phase == TouchPhase.Began || moveId == -1) { moveId = t.fingerId; moveOrigin = pos; }
                moveVec = Vector2.ClampMagnitude((pos - moveOrigin) / (H * .1f), 1);
                mv = moveVec; moveSeen = true; continue;
            }
            if (pos.x >= W * .45f && t.phase == TouchPhase.Moved)
            { yaw += t.deltaPosition.x * .2f; pitch = Mathf.Clamp(pitch - t.deltaPosition.y * .2f, -10, 60); }
        }
        if (!moveSeen && Input.touchCount >= 0) { if (moveId != -1) moveId = -1; }

        transform.rotation = Quaternion.Euler(0, yaw, 0);
        Vector3 dir = Quaternion.Euler(0, yaw, 0) * new Vector3(mv.x, 0, mv.y);
        vy = cc.isGrounded ? -1f : vy - 20f * Time.deltaTime;
        cc.Move((dir * 6f + Vector3.up * vy) * Time.deltaTime);

        if (firing && Time.time >= nextFire) { nextFire = Time.time + .15f; Fire(); }
    }

    void Fire()
    {
        var cam = Camera.main.transform;
        if (Physics.Raycast(cam.position, cam.forward, out RaycastHit hit, 200f))
        {
            var e = hit.collider.GetComponent<Enemy>();
            if (e != null) e.Damage(25);
            var spark = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            Destroy(spark.GetComponent<Collider>());
            spark.transform.position = hit.point; spark.transform.localScale = Vector3.one * .3f;
            spark.GetComponent<Renderer>().material.color = Color.yellow;
            Destroy(spark, .1f);
        }
    }

    void LateUpdate()
    {
        var cam = Camera.main.transform;
        Vector3 target = transform.position + Vector3.up * 1.4f;
        cam.position = target + Quaternion.Euler(pitch, yaw, 0) * new Vector3(0, 0, -5f);
        cam.LookAt(target);
    }

    void OnGUI()
    {
        float W = Screen.width, H = Screen.height;
        GUI.skin.label.fontSize = (int)(H / 28); GUI.skin.box.fontSize = (int)(H / 30);
        GUI.Label(new Rect(20, 20, W, H / 20), "HP: " + Mathf.Max(0, (int)hp) + "   Kills: " + kills);
        float r = H * .12f;
        GUI.Box(new Rect(W * .85f - r, H * .8f - r, r * 2, r * 2), "FIRE");
        if (moveId != -1) GUI.Box(new Rect(moveOrigin.x - 40, H - moveOrigin.y - 40, 80, 80), "");
        if (hp <= 0) GUI.Label(new Rect(W * .25f, H * .4f, W, H / 10), "GAME OVER - tap to restart");
    }
}

public class Enemy : MonoBehaviour
{
    float hp = 50;
    public static void Spawn()
    {
        var e = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        e.GetComponent<Renderer>().material.color = Color.red;
        float a = Random.value * 6.28f, d = Random.Range(25, 60);
        e.transform.position = new Vector3(Mathf.Cos(a) * d, 1, Mathf.Sin(a) * d);
        e.AddComponent<Enemy>();
    }
    public void Damage(float d)
    {
        hp -= d;
        if (hp <= 0) { Soldier.I.kills++; Destroy(gameObject); Spawn(); }
    }
    void Update()
    {
        var s = Soldier.I; if (s == null || s.hp <= 0) return;
        Vector3 to = s.transform.position - transform.position; to.y = 0;
        if (to.magnitude > 1.8f) transform.position += to.normalized * 3f * Time.deltaTime;
        else s.hp -= 15f * Time.deltaTime;
        transform.position = new Vector3(transform.position.x, 1, transform.position.z);
    }
}
