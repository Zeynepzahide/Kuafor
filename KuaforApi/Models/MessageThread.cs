namespace KuaforApi.Models;

public class MessageThread
{
    public int Id { get; set; }

    public int SalonId { get; set; }
    public Salon? Salon { get; set; }

    public int CustomerId { get; set; }
    public User? Customer { get; set; }

    public string Type { get; set; } = "Inquiry";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public List<ChatMessage> Messages { get; set; } = new();
}

public class ChatMessage
{
    public int Id { get; set; }

    public int MessageThreadId { get; set; }
    public MessageThread? MessageThread { get; set; }

    public int SenderId { get; set; }
    public User? Sender { get; set; }

    public string Content { get; set; } = string.Empty;
    public bool IsRead { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
