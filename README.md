# IU_CloudProgramming
This is a repo with the purpose of studying Cloud Programming. The goal is to build an automatic scaling cloud infrastructure, hosting a simple static website, wich is accessible worldwide with low latency. The infrastructure is beeing coded in Terraform.

____
Dieses Repo dient dem Studieren von Cloud-Programmierung. Ziel ist der Aufbau einer automatisch skalierenden Cloud-Infrastruktur, die eine einfache statische Website hostet, welche weltweit mit geringer Latenz erreichbar ist. Die Infrastruktur wird mit Terraform implementiert.

Dieses Programm ist im Rahmen des Studiums *Angewandte Künstliche Intelligenz* an der IU Internationalen Hochschule entstanden. Es wurde im Kurs "Cloud Programming" von Florian Erik Janssens entworfen und programmiert. Das Programm dient ausschließlich Lernzwecken.

GitHub-Repository: https://github.com/printhellogithub/IU_CloudProgramming

Das Ergebnis ist unter [cactify.florianjanssens.de](https://cactify.florianjanssens.de/) erreichbar.

## Installationsanleitung

### Voraussetzungen

- Die Terraform CLI (1.2.0+) muss installiert sein
- Die AWS CLI muss installiert sein
- Ein AWS-Konto und zugehörige Anmeldeinformationen, mit denen Sie Ressourcen in der Region `us-east-1` erstellen dürfen, müssen vorhanden sein
- Im verwendeten AWS-Account (passend zu den AWS-CLI-Credentials) muss in Route 53 eine Public Hosted Zone für eine Domain vorhanden sein, die unter Ihrer Verwaltung steht

### Das Deployment reproduzieren

1. **GitHub-Repo klonen oder herunterladen:** Um das Programm herunterzuladen, laden Sie die ZIP-Datei des Repos vom GitHub Repo, die beim grünen Code-Button bereitgestellt wird. Entpacken Sie die ZIP-Datei. Falls git installiert sein sollte, können Sie das GitHub-Repo mit `git clone https://github.com/printhellogithub/IU_CloudProgramming.git` klonen.
2. **Projektordner in CMD öffnen:** Öffnen Sie den entpackten Projektordner `IU_CloudProgramming-main` im Explorer. Dort können Sie Verzeichnisse wie `src` und `lamb-funct-package` sehen. Geben Sie `cmd` in die Adresszeile ein und drücken Sie Enter. Der Ordner wird in CMD geöffnet. Sie sollten beim Befehl `dir` jetzt Verzeichnisse wie `src` und `lamb-funct-package` sehen können.
3. Öffnen Sie `Variables.tf`, passen Sie die Domain an und geben Sie Ihre E-Mail-Adresse ein.
4. Öffnen Sie im Ordner `lamb-funct-package` die Datei `contact.py`: Passen Sie die globale Variable `MAIN_DOMAIN` an.
5. Melden Sie sich mit Ihren Zugangsdaten bei der AWS CLI an.
6. Jetzt können Sie die Befehle zum Deployment durchführen:
   1. `terraform init` (downloadet und installiert die angegebenen Provider)
   2. `terraform validate` (bestätigt, dass es sich um eine valide Terraform-Konfiguration handelt)
   3. `terraform plan` (plant die Schritte des Deployments)
   4. `terraform apply` (bereitet das Deployment vor und muss bestätigt werden)

### Das Deployment löschen

Wenn Sie die Cloud-Architektur wieder löschen möchten, geben Sie den Befehl `terraform destroy` ein.