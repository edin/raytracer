using System.Collections.Generic;
using System.IO;
using System.Xml.Serialization;

namespace Tools.Models
{
    [XmlRoot(ElementName = "Build")]
    public class Build
    {
        [XmlAttribute(AttributeName = "Process")]
        public string Process { get; set; }
        [XmlAttribute(AttributeName = "Arguments")]
        public string Arguments { get; set; }
    }

    [XmlRoot(ElementName = "Run")]
    public class Run
    {
        [XmlAttribute(AttributeName = "Process")]
        public string Process { get; set; }
        [XmlAttribute(AttributeName = "Arguments")]
        public string Arguments { get; set; }
    }

    [XmlRoot(ElementName = "Command")]
    public class Command
    {
        [XmlElement(ElementName = "Build")]
        public Build Build { get; set; }
        [XmlElement(ElementName = "Run")]
        public Run Run { get; set; }
        [XmlAttribute(AttributeName = "Name")]
        public string Name { get; set; }
    }

    [XmlRoot(ElementName = "Project")]
    public class Project
    {
        [XmlElement(ElementName = "Command")]
        public List<Command> Commands { get; set; }
        [XmlAttribute(AttributeName = "Path")]
        public string Path { get; set; }
        [XmlAttribute(AttributeName = "Language")]
        public string Language { get; set; }
    }

    [XmlRoot(ElementName = "Projects")]
    public class ProjectCollection
    {
        [XmlElement(ElementName = "Project")]
        public List<Project> Projects { get; set; }
    }

    public class ProjectDocument
    {
        public static ProjectCollection Load()
        {
            using var fileStream = File.Open("projects.xml", FileMode.Open);
            XmlSerializer serializer = new XmlSerializer(typeof(ProjectCollection));
            var document = (ProjectCollection)serializer.Deserialize(fileStream);
            return document;
        }
    }
}
